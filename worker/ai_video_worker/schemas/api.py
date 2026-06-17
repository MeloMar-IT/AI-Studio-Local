from datetime import datetime
from typing import Dict, List, Optional

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
    family: str
    version: Optional[str] = None
    expected_files: List[str]
    download_urls: Optional[Dict[str, str]] = None
    memory_requirement_gb: Optional[int] = None
    supported_modes: List[str]
    recommended_hardware: Optional[str] = None
    local_path: Optional[str] = None
    installed: bool = False
    recommended: bool = False
    missing_files: List[str] = []
    status: str = "missing" # installed, missing, partial, error


class ModelsResponse(BaseModel):
    models: List[ModelProfile]
    models_dir: str


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
    composed_prompt_path: Optional[str] = None
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


class ModelValidationRequest(BaseModel):
    path: str


class ModelValidationResponse(BaseModel):
    matched_profile: Optional[ModelProfile] = None
    missing_files: List[str] = []
    warnings: List[str] = []
    can_use: bool = False
    message: str


class ModelImportRequest(BaseModel):
    path: str
    copy_files: bool = True
    model_id: Optional[str] = None


class ModelDownloadRequest(BaseModel):
    model_id: str


class ProgressEvent(BaseModel):
    job_id: str
    stage: str
    percentage: Optional[float] = None
    message: str
    timestamp: datetime
