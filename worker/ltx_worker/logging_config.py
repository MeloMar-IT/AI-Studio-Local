import logging
import sys
import os
from datetime import datetime

from ltx_worker.config import settings

def setup_logging():
    level = getattr(logging, settings.log_level.upper())

    # Standard format for console
    console_format = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"

    handlers = [logging.StreamHandler(sys.stdout)]

    # Add file logging if configured
    if hasattr(settings, "log_file") and settings.log_file:
        log_dir = os.path.dirname(settings.log_file)
        if log_dir:
            os.makedirs(log_dir, exist_ok=True)
        handlers.append(logging.FileHandler(settings.log_file))

    logging.basicConfig(
        level=level,
        format=console_format,
        handlers=handlers,
    )

    # Set levels for noisy libraries
    logging.getLogger("uvicorn").setLevel(max(level, logging.INFO))
    logging.getLogger("fastapi").setLevel(max(level, logging.INFO))
    logging.getLogger("uvicorn.access").setLevel(max(level, logging.INFO))


logger = logging.getLogger("ltx-worker")
