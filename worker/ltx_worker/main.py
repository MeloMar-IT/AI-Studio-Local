import uvicorn
import time
from ltx_worker.api import router, http_exception_handler, generic_exception_handler
from ltx_worker.config import settings
from ltx_worker.logging_config import setup_logging, logger
from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError

# Initialize logging
setup_logging()

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
    # In production, we don't want reload
    should_reload = settings.environment == "development"

    uvicorn.run(
        "ltx_worker.main:app",
        host=settings.host,
        port=settings.port,
        reload=should_reload
    )
