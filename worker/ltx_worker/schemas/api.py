from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel


class HealthResponse(BaseModel):
    status: str
    version: str
    uptime: float


class HardwareResponse(BaseModel):
    device: str
    chip: str
    total_memory_gb: float
    free_memory_gb: float
    os_version: str


class ModelProfile(BaseModel):
    id: str
    name: str
    description: str
    recommended: bool = False


class ModelsResponse(BaseModel):
    models: List[ModelProfile]


class GenerationRequest(BaseModel):
    prompt: str
    negative_prompt: Optional[str] = None
    width: int = 704
    height: int = 480
    num_frames: int = 161
    steps: int = 20
    guidance_scale: float = 3.0
    seed: Optional[int] = None
    model_id: str


class JobStatus(BaseModel):
    job_id: str
    status: str
    progress: float
    message: str
    created_at: datetime
    updated_at: datetime
    result_url: Optional[str] = None
    error: Optional[str] = None
