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
    os_name: str
    os_version: str
    python_version: str
    mlx_available: bool
    pytorch_available: bool
    ffmpeg_available: bool
    free_disk_models_gb: float
    free_disk_outputs_gb: float
    status: str  # ready, warning, unsupported
    messages: List[str]


class ModelProfile(BaseModel):
    id: str
    name: str
    description: str
    recommended: bool = False


class ModelsResponse(BaseModel):
    models: List[ModelProfile]


class ErrorDetail(BaseModel):
    code: str
    message: str
    detail: Optional[str] = None
    action: Optional[str] = None


class ErrorResponse(BaseModel):
    error: ErrorDetail


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
    project_id: Optional[str] = None
    scene_id: Optional[str] = None
    image_path: Optional[str] = None
    audio_path: Optional[str] = None
    video_path: Optional[str] = None
    retake_start_seconds: Optional[float] = None
    retake_end_seconds: Optional[float] = None


class JobStatus(BaseModel):
    job_id: str
    status: str
    progress: float
    message: str
    created_at: datetime
    updated_at: datetime
    result_url: Optional[str] = None
    error: Optional[str] = None
