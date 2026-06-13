import asyncio
import json
import uuid
from datetime import datetime
from typing import Dict, Optional, Any

from ltx_worker.logging_config import logger
from ltx_worker.schemas.api import JobStatus, GenerationRequest
from ltx_worker.engine.base import GenerationEngine, CancellationToken
from ltx_worker.engine.output import OutputManager


class JobStore:
    def __init__(self, engine: GenerationEngine, output_manager: OutputManager):
        self.jobs: Dict[str, JobStatus] = {}
        self.cancellation_tokens: Dict[str, CancellationToken] = {}
        self.engine = engine
        self.output_manager = output_manager

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
            "status": job.status,
            "request": request.model_dump(),
            "created_at": now,
        }
        self.output_manager.save_metadata(job_id, metadata)

        token = CancellationToken()
        self.cancellation_tokens[job_id] = token

        # Start generation task
        asyncio.create_task(self.run_job(job_id, request, token))
        return job_id

    def get_job(self, job_id: str) -> Optional[JobStatus]:
        return self.jobs.get(job_id)

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
                        except Exception as e:
                            logger.error(f"Failed to update metadata for cancelled job {job_id}: {e}")

                return True
            else:
                # Token already cancelled but maybe status not updated yet or it was already terminal
                return False
        return False

    async def run_job(self, job_id: str, request: GenerationRequest, token: CancellationToken):
        def progress_callback(status: str, progress: float, message: str):
            if job_id in self.jobs:
                job = self.jobs[job_id]
                job.status = status
                job.progress = progress
                job.message = message
                job.updated_at = datetime.now()
                logger.debug(f"Job {job_id} progress: {status} ({progress*100}%)")

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
                        self.output_manager.save_metadata(job_id, metadata)
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

                # Update final metadata
                metadata_path = self.output_manager.get_metadata_path(job_id)
                if metadata_path.exists():
                    with open(metadata_path, "r") as f:
                        metadata = json.load(f)
                else:
                    metadata = {
                        "job_id": job_id,
                        "request": request.model_dump(),
                        "created_at": job.created_at,
                    }

                metadata.update({
                    "status": "completed",
                    "progress": 1.0,
                    "completed_at": datetime.now(),
                    "output_path": result_path,
                    "result_url": job.result_url
                })
                self.output_manager.save_metadata(job_id, metadata)

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
                                "request": request.model_dump(),
                                "created_at": job.created_at,
                            }
                        metadata.update({
                            "status": "failed",
                            "error": str(e),
                            "updated_at": job.updated_at
                        })
                        self.output_manager.save_metadata(job_id, metadata)
                    except Exception as meta_e:
                        logger.error(f"Failed to update error metadata for job {job_id}: {meta_e}")

        finally:
            if job_id in self.cancellation_tokens:
                del self.cancellation_tokens[job_id]

job_store = None # Will be initialized in api.py or main.py
