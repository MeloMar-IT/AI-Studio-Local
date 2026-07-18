import logging
import sys
import os
from datetime import datetime

from ai_video_worker.config import settings

# Define TRACE level
TRACE_LEVEL = 5
logging.addLevelName(TRACE_LEVEL, "TRACE")

def trace(self, message, *args, **kws):
    if self.isEnabledFor(TRACE_LEVEL):
        self._log(TRACE_LEVEL, message, args, **kws)

logging.Logger.trace = trace

def setup_logging():
    level_name = settings.log_level.upper()
    if level_name == "TRACE":
        level = TRACE_LEVEL
    else:
        level = getattr(logging, level_name)

    # Standard format for console and file
    version = getattr(settings, "version", "unknown")
    console_format = f"%(asctime)s - %(name)s - v{version} - [%(process)d] - %(threadName)s - %(levelname)s - %(message)s"

    handlers = [logging.StreamHandler(sys.stdout)]
    sys.stdout.reconfigure(line_buffering=True)
    sys.stderr.reconfigure(line_buffering=True)

    # Add file logging if configured
    if hasattr(settings, "log_file") and settings.log_file:
        # Use absolute path if possible or ensure it's relative to worker root
        log_path = settings.log_file
        if not os.path.isabs(log_path):
             # worker/ai_video_worker/logging_config.py -> worker/ -> root/
             base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
             log_path = os.path.join(base_dir, "logs", "ai-studio-local.log")

        log_dir = os.path.dirname(log_path)
        if log_dir and not os.path.isdir(log_dir):
            try:
                os.makedirs(log_dir, exist_ok=True)
            except FileExistsError:
                if not os.path.islink(log_dir):
                    raise
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
