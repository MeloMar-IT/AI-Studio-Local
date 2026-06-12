from pydantic import ConfigDict
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "LTX Studio Local Worker"
    version: str = "0.1.0"
    api_prefix: str = ""
    host: str = "127.0.0.1"
    port: int = 8000

    # Engine configuration
    engine_type: str = "mock"  # "mock" or "ltx"
    output_dir: str = "outputs"

    model_config = ConfigDict(env_prefix="LTX_WORKER_")


settings = Settings()
