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

    def save_metadata(self, job_id: str, metadata: Dict[str, Any]):
        metadata_path = self.get_metadata_path(job_id)
        with open(metadata_path, "w") as f:
            json.dump(metadata, f, indent=2, default=str)

    def cleanup_job(self, job_id: str):
        job_dir = self.get_job_dir(job_id)
        if job_dir.exists():
            shutil.rmtree(job_dir)
