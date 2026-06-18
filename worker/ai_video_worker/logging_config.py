import logging
import sys
import os
from datetime import datetime

from ai_video_worker.config import settings

def setup_logging():
    level = getattr(logging, settings.log_level.upper())

    # Standard format for console and file
    console_format = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"

    handlers = [logging.StreamHandler(sys.stdout)]

    # Add file logging if configured
    if hasattr(settings, "log_file") and settings.log_file:
        # Use absolute path if possible or ensure it's relative to worker root
        log_path = settings.log_file
        if not os.path.isabs(log_path):
             # worker/ai_video_worker/logging_config.py -> worker/ -> root/
             base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
             log_path = os.path.join(base_dir, "logs", "ai-studio-local.log")

        log_dir = os.path.dirname(log_path)
        if log_dir:
            os.makedirs(log_dir, exist_ok=True)
        handlers.append(logging.FileHandler(log_path))

    logging.basicConfig(
        level=level,
        format=console_format,
        handlers=handlers,
    )

    # Set levels for noisy libraries
    logging.getLogger("uvicorn").setLevel(max(level, logging.INFO))
    logging.getLogger("fastapi").setLevel(max(level, logging.INFO))
    logging.getLogger("uvicorn.access").setLevel(max(level, logging.INFO))


logger = logging.getLogger("ai-video-worker")
