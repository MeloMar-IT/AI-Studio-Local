import uvicorn
from ltx_worker.api import router, http_exception_handler, generic_exception_handler
from ltx_worker.config import settings
from ltx_worker.logging_config import setup_logging
from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError

# Initialize logging
setup_logging()

app = FastAPI(
    title=settings.app_name,
    version=settings.version,
)

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
    uvicorn.run(
        "ltx_worker.main:app", host=settings.host, port=settings.port, reload=True
    )
