import logging
import sys
import os
from datetime import datetime

from ltx_worker.config import settings
11:
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
