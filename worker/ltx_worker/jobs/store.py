import asyncio
import uuid
from datetime import datetime
from typing import Dict, Optional

from ltx_worker.logging_config import logger
from ltx_worker.schemas.api import JobStatus


class JobStore:
    def __init__(self):
        self.jobs: Dict[str, JobStatus] = {}

    def create_job(self) -> str:
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
        # Start background simulation
        asyncio.create_task(self.simulate_job(job_id))
        return job_id

    def get_job(self, job_id: str) -> Optional[JobStatus]:
        return self.jobs.get(job_id)

    async def simulate_job(self, job_id: str):
        stages = [
            ("checking_hardware", 0.1, "Checking hardware compatibility..."),
            ("loading_model", 0.2, "Loading LTX model into memory..."),
            ("preparing_inputs", 0.3, "Preparing generation inputs..."),
            (
                "generating_video",
                0.4,
                "Generating video frames (this may take a while)...",
            ),
            ("generating_video", 0.7, "Finishing video generation..."),
            ("encoding_output", 0.9, "Encoding final MP4..."),
            ("completed", 1.0, "Generation completed successfully."),
        ]

        try:
            for status, progress, message in stages:
                await asyncio.sleep(2)  # Simulate work
                if job_id not in self.jobs:
                    break

                job = self.jobs[job_id]
                job.status = status
                job.progress = progress
                job.message = message
                job.updated_at = datetime.now()

                if status == "completed":
                    job.result_url = f"/outputs/{job_id}.mp4"

                logger.info(f"Job {job_id} updated: {status} ({progress * 100}%)")
        except Exception as e:
            logger.error(f"Error simulating job {job_id}: {e}")
            if job_id in self.jobs:
                job = self.jobs[job_id]
                job.status = "failed"
                job.error = str(e)
                job.updated_at = datetime.now()


job_store = JobStore()
