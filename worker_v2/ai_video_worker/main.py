import uvicorn
import time
import os
from ai_video_worker.logging_config import setup_logging

# Initialize logging
setup_logging()

from ai_video_worker.api import router, http_exception_handler, generic_exception_handler
from ai_video_worker.config import settings
from ai_video_worker.logging_config import logger
from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError

def print_startup_report():
    from ai_video_worker.utils.profiler import get_hardware_profile
    profile = get_hardware_profile()

    report = [
        "="*60,
        "AI VIDEO WORKER STARTUP REPORT",
        "="*60,
        f"Status:         {profile['status'].upper()}",
        f"Version:        {settings.version}",
        f"Engine:         {settings.engine_type.upper()}",
        f"OS:             {profile['os_name']} {profile['os_version']}",
        f"Python:         {profile['python_version']}",
        f"Python Path:    {profile['python_path']}",
        f"Venv Path:      {profile['venv_path']}",
        f"Device:         {profile['device']}",
        f"Chip:           {profile['chip']}",
        f"Memory:         {profile['total_memory_gb']} GB total ({profile['free_memory_gb']} GB free)",
        f"MLX Available:  {'✅' if profile['mlx_available'] else '❌'}",
        f"FFmpeg:         {'✅' if profile['ffmpeg_available'] else '❌'}",
        f"Libraries:      {', '.join([f'{lib}:{'✅' if ok else '❌'}' for lib, ok in profile['libraries_status'].items()])}",
        f"Models Dir:     {os.path.abspath(settings.models_dir)}",
        f"Models Disk:    {profile['free_disk_models_gb']} GB free",
        "="*60
    ]

    if profile['messages']:
        report.append("MESSAGES / WARNINGS:")
        for msg in profile['messages']:
            report.append(f"  - {msg}")
        report.append("="*60)

    full_report = "\n".join(report)
    logger.info(full_report)

    if profile['status'] == "unsupported":
        logger.error("❌ CRITICAL: Hardware or OS is not supported. Worker may not function correctly.")

print_startup_report()

app = FastAPI(
    title=settings.app_name,
    version=settings.version,
)

@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    path = request.url.path
    if request.query_params:
        path += f"?{request.query_params}"

    logger.info(f"Incoming {request.method} {path}")
    if settings.log_level == "DEBUG":
        # We don't log the body here because it might be large or binary (for images)
        # but we can log headers
        logger.debug(f"Request headers: {dict(request.headers)}")
        if request.query_params:
            logger.debug(f"Query params: {dict(request.query_params)}")

    try:
        response = await call_next(request)
        process_time = (time.time() - start_time) * 1000
        logger.info(
            f"Completed {request.method} {path} - Status {response.status_code} - "
            f"Duration {process_time:.2f}ms"
        )
        return response
    except Exception as e:
        process_time = (time.time() - start_time) * 1000
        logger.error(
            f"Failed {request.method} {path} - Error: {str(e)} - "
            f"Duration {process_time:.2f}ms"
        )
        raise

app.add_exception_handler(HTTPException, http_exception_handler)
app.add_exception_handler(Exception, generic_exception_handler)

async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return await http_exception_handler(
        request,
        HTTPException(status_code=422, detail=exc.errors())
    )

app.add_exception_handler(RequestValidationError, validation_exception_handler)

app.include_router(router, prefix=settings.api_prefix)

if __name__ == "__main__":
    import sys
    # In production, we don't want reload
    should_reload = settings.environment == "development" and "--no-reload" not in sys.argv

    uvicorn.run(
        "ai_video_worker.main:app",
        host=settings.host,
        port=settings.port,
        reload=should_reload
    )
