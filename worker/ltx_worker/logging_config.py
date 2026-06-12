import logging
import sys


from ltx_worker.config import settings

def setup_logging():
    level = getattr(logging, settings.log_level.upper())
    logging.basicConfig(
        level=level,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        handlers=[logging.StreamHandler(sys.stdout)],
    )

    # Set levels for noisy libraries
    logging.getLogger("uvicorn").setLevel(max(level, logging.INFO))
    logging.getLogger("fastapi").setLevel(max(level, logging.INFO))


logger = logging.getLogger("ltx-worker")
