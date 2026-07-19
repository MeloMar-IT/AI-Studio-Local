import asyncio
import json
import uuid
import time
import os
import multiprocessing
import queue
from pathlib import Path
from datetime import datetime
from typing import Dict, Optional, Any, List

from ai_video_worker.logging_config import logger
from ai_video_worker.schemas.api import JobStatus, GenerationRequest
from ai_video_worker.engine.base import GenerationEngine, CancellationToken
from ai_video_worker.engine.output import OutputManager
from ai_video_worker.config import settings


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
            message="Job created. Queueing for execution...",
            created_at=now,
            updated_at=now,
        )
        self.jobs[job_id] = job

        # Write initial metadata as required by guidelines
        metadata = {
            "generation_id": job_id,
            "project_id": request.project_id,
            "scene_id": request.scene_id,
            "status": job.status,
            "timestamp": now.isoformat(),
            "model_id": request.model_id,
            "prompt": request.prompt,
            "composed_prompt": request.composed_prompt or request.prompt,
            "negative_prompt": request.negative_prompt,
            "resolution": f"{request.width}x{request.height}",
            "steps": request.steps,
            "guidance_scale": request.guidance_scale,
            "seed": request.seed,
            "duration": request.num_frames,
            "created_at": now.isoformat(),
            "updated_at": now.isoformat(),
            "loras": [lora.model_dump() for lora in request.loras] if request.loras else []
        }
        # Add voice clone reference path to metadata if present
        if request.voice_clone_reference_path:
            metadata["voice_clone_reference_path"] = request.voice_clone_reference_path
            self.output_manager.append_log(job_id, f"  - Voice Clone Reference: {request.voice_clone_reference_path}")

        self.output_manager.save_metadata(job_id, metadata)
        self.output_manager.append_log(job_id, f"Job initialized for scene {request.scene_id}")
        self.output_manager.append_log(job_id, f"Initial Request Parameters:")
        self.output_manager.append_log(job_id, f"  - Prompt: {request.prompt}")
        if request.composed_prompt:
             self.output_manager.append_log(job_id, f"  - Composed Prompt: {request.composed_prompt}")
        self.output_manager.append_log(job_id, f"  - Negative Prompt: {request.negative_prompt}")
        self.output_manager.append_log(job_id, f"  - Model ID: {request.model_id}")
        self.output_manager.append_log(job_id, f"  - Resolution: {request.width}x{request.height}")
        self.output_manager.append_log(job_id, f"  - Steps: {request.steps}")
        self.output_manager.append_log(job_id, f"  - Guidance Scale: {request.guidance_scale}")
        self.output_manager.append_log(job_id, f"  - Seed: {request.seed}")
        self.output_manager.append_log(job_id, f"  - Num Frames: {request.num_frames}")
        if request.loras:
            self.output_manager.append_log(job_id, f"  - LoRAs: {metadata['loras']}")

        token = CancellationToken()
        self.cancellation_tokens[job_id] = token

        # Start generation task in background
        asyncio.create_task(self.run_job(job_id, request, token))
        logger.info(f"Job {job_id} started background execution.")
        return job_id

    def create_training_job(self, request: Any) -> str:
        job_id = str(uuid.uuid4())
        now = datetime.now()
        job = JobStatus(
            job_id=job_id,
            status="preparing_training",
            progress=0.0,
            message="Training job created. Queueing for execution...",
            created_at=now,
            updated_at=now,
        )
        self.jobs[job_id] = job

        # Write initial metadata
        metadata = {
            "training_id": job_id,
            "project_id": request.project_id,
            "element_id": request.element_id,
            "element_type": request.element_type,
            "status": job.status,
            "timestamp": now.isoformat(),
            "model_id": request.model_id or settings.default_model_id,
            "steps": request.steps,
            "learning_rate": request.learning_rate,
            "rank": request.rank,
            "trigger_word": request.trigger_word,
            "training_data_paths": request.training_data_paths,
            "created_at": now.isoformat(),
            "updated_at": now.isoformat()
        }
        self.output_manager.save_metadata(job_id, metadata)
        self.output_manager.append_log(job_id, f"LoRA Training job initialized for element {request.element_id}")
        self.output_manager.append_log(job_id, f"Training Parameters:")
        self.output_manager.append_log(job_id, f"  - Element: {request.element_id} ({request.element_type})")
        self.output_manager.append_log(job_id, f"  - Steps: {request.steps}")
        self.output_manager.append_log(job_id, f"  - Rank: {request.rank}")
        self.output_manager.append_log(job_id, f"  - Trigger Word: {request.trigger_word}")

        token = CancellationToken()
        self.cancellation_tokens[job_id] = token

        # Start training task in background
        asyncio.create_task(self.run_training_job(job_id, request, token))
        logger.info(f"Training job {job_id} started background execution.")
        return job_id

    async def run_training_job(self, job_id: str, request: Any, token: CancellationToken):
        logger.info(f"Running training job {job_id}")

        def progress_callback(status, progress, message):
            self.update_job_status(job_id, status, progress, message)

        try:
            output_dir = os.path.join(settings.output_dir, "loras", request.element_id)
            os.makedirs(output_dir, exist_ok=True)

            lora_path = await self.engine.train_lora(
                request,
                output_dir,
                progress_callback=progress_callback,
                cancellation_token=token
            )

            if token.is_cancelled:
                self.update_job_status(job_id, "cancelled", 1.0, "Training cancelled by user")
            else:
                self.update_job_status(job_id, "completed", 1.0, "Training completed successfully", result_url=lora_path)

                # Update metadata with result
                metadata_path = self.output_manager.get_metadata_path(job_id)
                if metadata_path.exists():
                    with open(metadata_path, "r") as f:
                        metadata = json.load(f)
                    metadata["status"] = "completed"
                    metadata["result_url"] = lora_path
                    metadata["updated_at"] = datetime.now().isoformat()
                    self.output_manager.save_metadata(job_id, metadata)

        except Exception as e:
            logger.exception(f"Training job {job_id} failed: {e}")
            self.update_job_status(job_id, "failed", 1.0, f"Training failed: {str(e)}", error=str(e))

    def get_job(self, job_id: str) -> Optional[JobStatus]:
        return self.jobs.get(job_id)

    async def subscribe(self, job_id: str):
        """Subscribe to progress events for a job."""
        logger.info(f"New subscription for job events: {job_id}")
        # Use a larger queue size to prevent drops if the app is slow to consume
        queue = asyncio.Queue(maxsize=100)
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
                    "result_url": job.result_url,
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

    def update_job_status(self, job_id: str, status: str, progress: float, message: str, error: Optional[str] = None, result_url: Optional[str] = None):
        """Update job status and notify listeners."""
        if job_id not in self.jobs:
            logger.warning(f"Attempted to update status for non-existent job {job_id}")
            return

        job = self.jobs[job_id]
        job.status = status
        job.progress = progress
        job.message = message
        if error:
            job.error = error
        if result_url:
            job.result_url = result_url
        job.updated_at = datetime.now()

        logger.info(f"Job {job_id} updated: {status} ({progress*100:.1f}%) - {message}")

        # Notify listeners
        if job_id in self.listeners:
            event = {
                "job_id": job_id,
                "stage": status,
                "percentage": progress,
                "message": message,
                "result_url": result_url,
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
            if result_url:
                metadata["result_url"] = result_url
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

    async def run_job(self, job_id: str, request: GenerationRequest, token: CancellationToken):
        last_log_time = 0  # Initialize to 0 to ensure the first progress update is always logged

        # Setup job-specific logging for the engine
        if hasattr(self.engine, "set_job_logger"):
            def job_logger(msg):
                self.output_manager.append_log(job_id, msg)
            self.engine.set_job_logger(job_logger)

        def progress_callback(status: str, progress: float, message: str):
            nonlocal last_log_time
            if job_id in self.jobs:
                job = self.jobs[job_id]
                job.status = status
                job.progress = progress
                job.message = message
                job.updated_at = datetime.now()

                # Check if 5 seconds have passed since the last log
                current_time = time.time()
                if current_time - last_log_time >= 5:
                    logger.info(f"Job {job_id} progress: {status} ({progress*100:.1f}%) - {message}")
                    last_log_time = current_time

                # Always log progress in DEBUG mode
                logger.debug(f"Job {job_id} progress: {status} ({progress*100:.1f}%) - {message}")

                # Notify listeners
                if job_id in self.listeners:
                    event = {
                        "job_id": job_id,
                        "stage": status,
                        "percentage": progress,
                        "message": message,
                        "result_url": getattr(job, "result_url", None),
                        "timestamp": job.updated_at.isoformat()
                    }
                    for q in self.listeners[job_id]:
                        try:
                            q.put_nowait(event)
                        except Exception as e:
                            logger.error(f"Failed to push event to listener for job {job_id}: {e}")

                # Update metadata with progress
                try:
                    metadata_path = self.output_manager.get_metadata_path(job_id)
                    if metadata_path.exists():
                        with open(metadata_path, "r") as f:
                            metadata = json.load(f)
                        metadata["status"] = status
                        metadata["progress"] = progress
                        metadata["message"] = message
                        metadata["error"] = getattr(job, "error", None)
                        metadata["updated_at"] = job.updated_at.isoformat()

                        # Add progress event
                        if "progress_events" not in metadata:
                            metadata["progress_events"] = []
                        metadata["progress_events"].append({
                            "status": status,
                            "progress": progress,
                            "message": message,
                            "error": getattr(job, "error", None),
                            "timestamp": job.updated_at.isoformat()
                        })

                        self.output_manager.save_metadata(job_id, metadata)
                        self.output_manager.append_log(job_id, f"Progress: {status} ({progress*100:.1f}%) - {message}")
                except Exception as e:
                    logger.error(f"Failed to update metadata for job {job_id}: {e}")

        try:
            from ai_video_worker.utils.models import is_model_installed

            if not is_model_installed(request.model_id):
                raise Exception(f"Model '{request.model_id}' is not installed. AI Studio Local is currently in offline-only mode. Please ensure the model files are present in the 'models/{request.model_id}' directory.")

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
                result_file = Path(result_path)
                if not result_file.is_file():
                    raise RuntimeError(f"Generation returned a missing output file: {result_path}")

                # Check for minimum file size to catch empty/broken files
                # 10KB is a very safe minimum for a short MP4
                if result_file.stat().st_size < 10000:
                    raise RuntimeError(
                        f"Generation returned an invalid or suspiciously small output: "
                        f"{result_file.stat().st_size} bytes"
                    )

                self.update_job_status(job_id, "completed", 1.0, "Job completed successfully")

                # Ensure result_url is set after update_job_status
                if job_id in self.jobs:
                    self.jobs[job_id].result_url = f"/outputs/{job_id}/output.mp4"
                    # Update metadata one last time with result_url
                    try:
                        metadata_path = self.output_manager.get_metadata_path(job_id)
                        if metadata_path.exists():
                            with open(metadata_path, "r") as f:
                                metadata = json.load(f)
                            metadata["result_url"] = self.jobs[job_id].result_url
                            self.output_manager.save_metadata(job_id, metadata)
                    except Exception:
                        pass
                logger.info(f"Job {job_id} completed successfully")
            else:
                raise Exception("Generation failed to produce output")

        except Exception as e:
            logger.error(f"Error running job {job_id}: {e}")
            if job_id in self.jobs:
                job = self.jobs[job_id]
                if job.status != "cancelled":
                    self.update_job_status(job_id, "failed", job.progress, str(e), error=str(e))

        finally:
            if job_id in self.cancellation_tokens:
                del self.cancellation_tokens[job_id]


job_store = None # Will be initialized in api.py or main.py
