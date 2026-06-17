import asyncio
import json
import uuid
from datetime import datetime
from typing import Dict, Optional, Any

from ai_video_worker.logging_config import logger
from ai_video_worker.schemas.api import JobStatus, GenerationRequest
from ai_video_worker.engine.base import GenerationEngine, CancellationToken
from ai_video_worker.engine.output import OutputManager


class JobStore:
    def __init__(self, engine: GenerationEngine, output_manager: OutputManager):
        self.jobs: Dict[str, JobStatus] = {}
        self.cancellation_tokens: Dict[str, CancellationToken] = {}
        self.engine = engine
        self.output_manager = output_manager
        self.listeners: Dict[str, List[asyncio.Queue]] = {}
        self._recover_jobs()

    def _recover_jobs(self):
        """Recover existing jobs from disk and mark interrupted ones."""
        job_ids = self.output_manager.list_jobs()
        for job_id in job_ids:
            try:
                metadata_path = self.output_manager.get_metadata_path(job_id)
                with open(metadata_path, "r") as f:
                    metadata = json.load(f)

                status = metadata.get("status", "failed")
                # If job was in a non-terminal state, mark as interrupted
                if status not in ["completed", "failed", "cancelled", "interrupted"]:
                    status = "interrupted"
                    metadata["status"] = status
                    metadata["error"] = "Job interrupted by worker restart"
                    metadata["updated_at"] = datetime.now()
                    self.output_manager.save_metadata(job_id, metadata)
                    self.output_manager.append_log(job_id, "Job marked as interrupted due to worker restart.")

                created_at = metadata.get("created_at")
                if isinstance(created_at, str):
                    created_at = datetime.fromisoformat(created_at)

                updated_at = metadata.get("updated_at")
                if isinstance(updated_at, str):
                    updated_at = datetime.fromisoformat(updated_at)
                else:
                    updated_at = created_at

                job = JobStatus(
                    job_id=job_id,
                    status=status,
                    progress=metadata.get("progress", 0.0),
                    message=metadata.get("message", ""),
                    created_at=created_at or datetime.now(),
                    updated_at=updated_at or datetime.now(),
                    result_url=metadata.get("result_url"),
                    error=metadata.get("error")
                )
                self.jobs[job_id] = job
            except Exception as e:
                logger.error(f"Failed to recover job {job_id}: {e}")

    def create_job(self, request: GenerationRequest) -> str:
        job_id = str(uuid.uuid4())
        now = datetime.now()
        job = JobStatus(
            job_id=job_id,
            status="preparing_prompt",
            progress=0.0,
            message="Initializing job...",
            created_at=now,
            updated_at=now,
        )
        self.jobs[job_id] = job

        # Write initial metadata
        metadata = {
            "job_id": job_id,
            "project_id": request.project_id,
            "scene_id": request.scene_id,
            "status": job.status,
            "request_summary": request.model_dump(exclude={"prompt", "negative_prompt"}),
            "model_profile": request.model_id, # In a real implementation we might store more profile info
            "composed_prompt_path": request.composed_prompt_path,
            "output_paths": {
                "video": str(self.output_manager.get_video_path(job_id)),
                "preview": str(self.output_manager.get_preview_path(job_id)),
            },
            "started_at": now,
            "created_at": now,
            "updated_at": now,
            "progress_events": []
        }
        self.output_manager.save_metadata(job_id, metadata)
        self.output_manager.append_log(job_id, f"Job created for scene {request.scene_id} in project {request.project_id}")

        token = CancellationToken()
        self.cancellation_tokens[job_id] = token

        # Start generation task
        asyncio.create_task(self.run_job(job_id, request, token))
        logger.info(f"Created job {job_id} for project {request.project_id}")
        return job_id

    def get_job(self, job_id: str) -> Optional[JobStatus]:
        return self.jobs.get(job_id)

    async def subscribe(self, job_id: str):
        """Subscribe to progress events for a job."""
        logger.info(f"New subscription for job events: {job_id}")
        queue = asyncio.Queue()
        if job_id not in self.listeners:
            self.listeners[job_id] = []
        self.listeners[job_id].append(queue)

        try:
            # Yield current state as first event if job exists
            job = self.get_job(job_id)
            if job:
                yield {
                    "job_id": job_id,
                    "stage": job.status,
                    "percentage": job.progress,
                    "message": job.message,
                    "timestamp": job.updated_at.isoformat()
                }

            # If job is already terminal, we're done
            if job and job.status in ["completed", "failed", "cancelled", "interrupted"]:
                logger.info(f"Job {job_id} is already in terminal state {job.status}, finishing subscription.")
                return

            while True:
                try:
                    event = await asyncio.wait_for(queue.get(), timeout=1.0)
                    yield event
                    if event["stage"] in ["completed", "failed", "cancelled", "interrupted"]:
                        logger.info(f"Job {job_id} reached terminal state {event['stage']}, finishing subscription.")
                        break
                except asyncio.TimeoutError:
                    # Check if job was removed or something while waiting
                    if job_id not in self.listeners:
                        logger.warning(f"Job {job_id} listeners entry removed, finishing subscription.")
                        break
                    # Send a tick to the generator to allow it to yield control if needed
                    # (Though SSE heartbeat handles the connection-level keepalive)
                    continue
        finally:
            if job_id in self.listeners:
                if queue in self.listeners[job_id]:
                    self.listeners[job_id].remove(queue)
                if not self.listeners[job_id]:
                    del self.listeners[job_id]
            logger.info(f"Subscription ended for job: {job_id}")

    def cancel_job(self, job_id: str) -> bool:
        if job_id in self.cancellation_tokens:
            token = self.cancellation_tokens[job_id]
            if not token.is_cancelled:
                token.cancel()
                if job_id in self.jobs:
                    job = self.jobs[job_id]
                    # Only change status if not already terminal
                    if job.status not in ["completed", "failed", "cancelled"]:
                        job.status = "cancelled"
                        job.message = "Job cancelled by user"
                        job.updated_at = datetime.now()

                        # Update metadata with cancellation
                        try:
                            metadata_path = self.output_manager.get_metadata_path(job_id)
                            if metadata_path.exists():
                                with open(metadata_path, "r") as f:
                                    metadata = json.load(f)
                                metadata["status"] = job.status
                                metadata["message"] = job.message
                                metadata["updated_at"] = job.updated_at
                                self.output_manager.save_metadata(job_id, metadata)
                                self.output_manager.append_log(job_id, "Job cancelled by user")
                        except Exception as e:
                            logger.error(f"Failed to update metadata for cancelled job {job_id}: {e}")

                return True
            else:
                # Token already cancelled but maybe status not updated yet or it was already terminal
                return False
        return False

    def update_job_status(self, job_id: str, status: str, progress: float, message: str):
        if job_id in self.jobs:
            job = self.jobs[job_id]
            job.status = status
            job.progress = progress
            job.message = message
            job.updated_at = datetime.now()
            logger.info(f"Job {job_id} progress: {status} ({progress*100}%)")

            # Notify listeners
            if job_id in self.listeners:
                event = {
                    "job_id": job_id,
                    "stage": status,
                    "percentage": progress,
                    "message": message,
                    "timestamp": job.updated_at.isoformat()
                }
                for queue in self.listeners[job_id]:
                    queue.put_nowait(event)

            # Update metadata
            try:
                metadata_path = self.output_manager.get_metadata_path(job_id)
                # It's possible the job dir doesn't exist yet for some job types,
                # but update_job_status should handle it.
                if metadata_path.exists():
                    with open(metadata_path, "r") as f:
                        metadata = json.load(f)
                    metadata["status"] = status
                    metadata["progress"] = progress
                    metadata["message"] = message
                    metadata["updated_at"] = job.updated_at.isoformat()

                    # Add progress event if it's a generation job
                    if "progress_events" in metadata:
                        metadata["progress_events"].append({
                            "status": status,
                            "progress": progress,
                            "message": message,
                            "timestamp": job.updated_at.isoformat()
                        })

                    self.output_manager.save_metadata(job_id, metadata)
            except Exception as e:
                logger.error(f"Failed to update metadata for job {job_id}: {e}")

    async def run_job(self, job_id: str, request: GenerationRequest, token: CancellationToken):
        def progress_callback(status: str, progress: float, message: str):
            if job_id in self.jobs:
                job = self.jobs[job_id]
                job.status = status
                job.progress = progress
                job.message = message
                job.updated_at = datetime.now()
                logger.info(f"Job {job_id} progress: {status} ({progress*100}%)")

                # Notify listeners
                if job_id in self.listeners:
                    event = {
                        "job_id": job_id,
                        "stage": status,
                        "percentage": progress,
                        "message": message,
                        "timestamp": job.updated_at.isoformat()
                    }
                    for queue in self.listeners[job_id]:
                        queue.put_nowait(event)

                # Update metadata with progress
                try:
                    metadata_path = self.output_manager.get_metadata_path(job_id)
                    if metadata_path.exists():
                        with open(metadata_path, "r") as f:
                            metadata = json.load(f)
                        metadata["status"] = status
                        metadata["progress"] = progress
                        metadata["message"] = message
                        metadata["updated_at"] = job.updated_at

                        # Add progress event
                        if "progress_events" not in metadata:
                            metadata["progress_events"] = []
                        metadata["progress_events"].append({
                            "status": status,
                            "progress": progress,
                            "message": message,
                            "timestamp": job.updated_at
                        })

                        self.output_manager.save_metadata(job_id, metadata)
                        self.output_manager.append_log(job_id, f"Progress: {status} ({progress*100}%) - {message}")
                except Exception as e:
                    logger.error(f"Failed to update metadata for job {job_id}: {e}")

        try:
            output_path = str(self.output_manager.get_video_path(job_id))

            result_path = await self.engine.generate(
                request=request,
                output_path=output_path,
                progress_callback=progress_callback,
                cancellation_token=token
            )

            if token.is_cancelled:
                logger.info(f"Job {job_id} was cancelled")
                # Metadata already updated by cancel_job or progress_callback
                return

            if result_path:
                job = self.jobs[job_id]
                job.result_url = f"/outputs/{job_id}/output.mp4"
                job.status = "completed"
                job.progress = 1.0
                job.updated_at = datetime.now()

                # Update final metadata
                metadata_path = self.output_manager.get_metadata_path(job_id)
                if metadata_path.exists():
                    with open(metadata_path, "r") as f:
                        metadata = json.load(f)
                else:
                    metadata = {
                        "job_id": job_id,
                        "project_id": request.project_id,
                        "scene_id": request.scene_id,
                        "created_at": job.created_at,
                    }

                metadata.update({
                    "status": "completed",
                    "progress": 1.0,
                    "completed_at": job.updated_at,
                    "updated_at": job.updated_at,
                    "output_path": result_path,
                    "result_url": job.result_url
                })
                self.output_manager.save_metadata(job_id, metadata)
                self.output_manager.append_log(job_id, "Job completed successfully")

                logger.info(f"Job {job_id} completed successfully")
            else:
                raise Exception("Generation failed to produce output")

        except Exception as e:
            logger.error(f"Error running job {job_id}: {e}")
            if job_id in self.jobs:
                job = self.jobs[job_id]
                if job.status != "cancelled":
                    job.status = "failed"
                    job.error = str(e)
                    job.updated_at = datetime.now()

                    # Update metadata with failure
                    try:
                        metadata_path = self.output_manager.get_metadata_path(job_id)
                        if metadata_path.exists():
                            with open(metadata_path, "r") as f:
                                metadata = json.load(f)
                        else:
                            metadata = {
                                "job_id": job_id,
                                "project_id": request.project_id,
                                "scene_id": request.scene_id,
                                "created_at": job.created_at,
                            }
                        metadata.update({
                            "status": "failed",
                            "error": str(e),
                            "updated_at": job.updated_at
                        })
                        self.output_manager.save_metadata(job_id, metadata)
                        self.output_manager.append_log(job_id, f"Job failed: {e}")
                    except Exception as meta_e:
                        logger.error(f"Failed to update error metadata for job {job_id}: {meta_e}")

        finally:
            if job_id in self.cancellation_tokens:
                del self.cancellation_tokens[job_id]

    def update_job_status(self, job_id: str, status: str, progress: float, message: str, error: Optional[str] = None):
        """Thread-safe update of job status and notify listeners."""
        if job_id not in self.jobs:
            logger.warning(f"Attempted to update status for non-existent job {job_id}")
            return

        job = self.jobs[job_id]
        job.status = status
        job.progress = progress
        job.message = message
        if error:
            job.error = error
        job.updated_at = datetime.now()

        logger.info(f"Job {job_id} updated: {status} ({progress*100:.1f}%) - {message}")

        # Notify listeners
        if job_id in self.listeners:
            event = {
                "job_id": job_id,
                "stage": status,
                "percentage": progress,
                "message": message,
                "timestamp": job.updated_at.isoformat()
            }
            if error:
                event["error"] = error

            for queue in self.listeners[job_id]:
                try:
                    queue.put_nowait(event)
                except Exception as e:
                    logger.error(f"Failed to put event in queue for job {job_id}: {e}")

        # Update metadata on disk
        try:
            metadata_path = self.output_manager.get_metadata_path(job_id)
            # Create directory if it doesn't exist
            metadata_path.parent.mkdir(parents=True, exist_ok=True)

            metadata = {}
            if metadata_path.exists():
                try:
                    with open(metadata_path, "r") as f:
                        metadata = json.load(f)
                except Exception:
                    pass

            metadata.update({
                "job_id": job_id,
                "status": status,
                "progress": progress,
                "message": message,
                "updated_at": job.updated_at.isoformat(),
            })
            if error:
                metadata["error"] = error
            if "created_at" not in metadata:
                metadata["created_at"] = job.created_at.isoformat()

            # Add progress event
            if "progress_events" not in metadata:
                metadata["progress_events"] = []

            metadata["progress_events"].append({
                "status": status,
                "progress": progress,
                "message": message,
                "timestamp": job.updated_at.isoformat()
            })

            self.output_manager.save_metadata(job_id, metadata)
            self.output_manager.append_log(job_id, f"Status: {status} ({progress*100:.1f}%) - {message}")
        except Exception as e:
            logger.error(f"Failed to update metadata for job {job_id}: {e}")

job_store = None # Will be initialized in api.py or main.py
