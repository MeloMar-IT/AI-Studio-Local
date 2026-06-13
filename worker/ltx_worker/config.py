import logging
from pydantic import ConfigDict, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Literal
import os


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="LTX_WORKER_",
        env_file=".env",
        extra="ignore"
    )

    app_name: str = "LTX Studio Local Worker"
    version: str = "0.1.0"
    api_prefix: str = ""
    host: str = "127.0.0.1"
    port: int = 8000
    environment: Literal["development", "test", "production"] = "development"
    log_level: str = "INFO"

    # Engine configuration
    engine_type: Literal["mock", "ltx"] = "ltx"
    output_dir: str = "outputs"

    # Model configuration
    models_dir: str = "models"
    default_model_id: str = "ltx-2.3-distilled"
    default_generation_profile: str = "balanced"

    # Hardware requirements
    min_memory_gb: float = 16.0

    model_config = ConfigDict(env_prefix="LTX_WORKER_")

    @field_validator("log_level")
    @classmethod
    def validate_log_level(cls, v: str) -> str:
        v = v.upper()
        allowed = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
        if v not in allowed:
            raise ValueError(f"log_level must be one of {allowed}")
        return v

    @field_validator("output_dir", "models_dir")
    @classmethod
    def ensure_dir_exists(cls, v: str) -> str:
        # We don't necessarily want to create it here as it might be a relative path
        # that depends on the CWD when the worker starts, but we can validate it.
        # For MVP, we'll just return it and let the main.py handle directory creation.
        return v

    def setup_logging(self):
        logging.basicConfig(
            level=getattr(logging, self.log_level),
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )


settings = Settings()
