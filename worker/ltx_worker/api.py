import platform
import time

import psutil
from fastapi import APIRouter, HTTPException

from ltx_worker.config import settings
from ltx_worker.jobs.store import job_store
from ltx_worker.schemas.api import (
    GenerationRequest,
    HardwareResponse,
    HealthResponse,
    JobStatus,
    ModelProfile,
    ModelsResponse,
)

router = APIRouter()
start_time = time.time()


@router.get("/health", response_model=HealthResponse)
async def health():
    return HealthResponse(
        status="ok", version=settings.version, uptime=time.time() - start_time
    )


@router.get("/hardware", response_model=HardwareResponse)
async def hardware():
    # Mocked Apple Silicon info as requested
    mem = psutil.virtual_memory()
    return HardwareResponse(
        device="MacBook Pro",
        chip="Apple M2 Max",
        total_memory_gb=round(mem.total / (1024**3), 2),
        free_memory_gb=round(mem.available / (1024**3), 2),
        os_version=f"macOS {platform.mac_ver()[0]}",
    )


@router.get("/models", response_model=ModelsResponse)
async def get_models():
    return ModelsResponse(
        models=[
            ModelProfile(
                id="ltx-2.3-distilled",
                name="LTX-2.3 Distilled",
                description="Fast draft generation",
                recommended=True,
            ),
            ModelProfile(
                id="ltx-2.3-dev", name="LTX-2.3 Dev", description="Production quality"
            ),
            ModelProfile(
                id="ltx-2.3-quantized",
                name="LTX-2.3 Quantized",
                description="Memory optimized",
            ),
        ]
    )


@router.post("/generate/text-to-video", response_model=JobStatus)
async def text_to_video(request: GenerationRequest):
    job_id = job_store.create_job()
    job = job_store.get_job(job_id)
    if not job:
        raise HTTPException(status_code=500, detail="Failed to create job")
    return job


@router.get("/jobs/{job_id}", response_model=JobStatus)
async def get_job(job_id: str):
    job = job_store.get_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    return job
