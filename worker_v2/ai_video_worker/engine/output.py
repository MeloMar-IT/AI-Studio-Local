import os
import json
import shutil
from pathlib import Path
from datetime import datetime
from typing import Any, Dict, Optional

class OutputManager:
    def __init__(self, base_output_dir: str):
        self.base_output_dir = Path(base_output_dir)
        self.base_output_dir.mkdir(parents=True, exist_ok=True)

    def get_job_dir(self, job_id: str) -> Path:
        job_dir = self.base_output_dir / job_id
        job_dir.mkdir(parents=True, exist_ok=True)
        return job_dir

    def get_video_path(self, job_id: str) -> Path:
        return self.get_job_dir(job_id) / "output.mp4"

    def get_preview_path(self, job_id: str) -> Path:
        return self.get_job_dir(job_id) / "preview.jpg"

    def get_metadata_path(self, job_id: str) -> Path:
        return self.get_job_dir(job_id) / "metadata.json"

    def get_log_path(self, job_id: str) -> Path:
        return self.get_job_dir(job_id) / "job.log"

    def save_metadata(self, job_id: str, metadata: Dict[str, Any]):
        metadata_path = self.get_metadata_path(job_id)
        with open(metadata_path, "w") as f:
            json.dump(metadata, f, indent=2, default=str)

    def append_log(self, job_id: str, message: str):
        log_path = self.get_log_path(job_id)
        timestamp = datetime.now().isoformat()
        with open(log_path, "a") as f:
            f.write(f"[{timestamp}] {message}\n")

    def list_jobs(self) -> list[str]:
        if not self.base_output_dir.exists():
            return []
        return [d.name for d in self.base_output_dir.iterdir() if d.is_dir() and (d / "metadata.json").exists()]

    def cleanup_job(self, job_id: str):
        job_dir = self.get_job_dir(job_id)
        if job_dir.exists():
            shutil.rmtree(job_dir)
