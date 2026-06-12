import uvicorn
from fastapi import FastAPI

from ltx_worker.api import router
from ltx_worker.config import settings
from ltx_worker.logging_config import setup_logging

# Initialize logging
setup_logging()

app = FastAPI(
    title=settings.app_name,
    version=settings.version,
)

app.include_router(router, prefix=settings.api_prefix)

if __name__ == "__main__":
    uvicorn.run(
        "ltx_worker.main:app", host=settings.host, port=settings.port, reload=True
    )
