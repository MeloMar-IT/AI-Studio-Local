import logging
from pydantic import ConfigDict, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Literal
import os


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="AI_VIDEO_WORKER_",
        env_file=".env",
        extra="ignore"
    )

    app_name: str = "AI Studio Local Worker"
    version: str = "0.1.1"
    api_prefix: str = ""
    host: str = "127.0.0.1"
    port: int = 8000
    environment: Literal["development", "test", "production"] = "production"
    log_level: str = "TRACE"
    log_file: str = "../logs/ai-studio-local.log"

    # Engine configuration
    engine_type: Literal["mock", "ltx"] = "ltx"
    output_dir: str = "outputs"

    # Model configuration
    models_dir: str = "models"
    default_model_id: str = "ltx-video-av-q4"
    default_generation_profile: str = "balanced"

    # Hardware requirements
    min_memory_gb: float = 16.0

    model_config = ConfigDict(env_prefix="AI_VIDEO_WORKER_")

    @field_validator("log_level")
    @classmethod
    def validate_log_level(cls, v: str) -> str:
        v = v.upper()
        allowed = ["TRACE", "DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
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
        from ai_video_worker.logging_config import setup_logging as init_logging
        init_logging()


settings = Settings()
