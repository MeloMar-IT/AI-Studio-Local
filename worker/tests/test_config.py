import pytest
from ai_video_worker.config import Settings
from pydantic import ValidationError

def test_default_config_creation():
    settings = Settings()
    assert settings.app_name == "AI Studio Local Worker"
    assert settings.host == "127.0.0.1"
    assert settings.port == 8000
    assert settings.log_level == "INFO"

def test_config_validation():
    # Test valid log level
    settings = Settings(log_level="debug")
    assert settings.log_level == "DEBUG"

    # Test invalid log level
    with pytest.raises(ValidationError):
        Settings(log_level="INVALID")

def test_environment_specific_config(monkeypatch):
    monkeypatch.setenv("AI_VIDEO_WORKER_LOG_LEVEL", "DEBUG")
    monkeypatch.setenv("AI_VIDEO_WORKER_PORT", "9000")

    settings = Settings()
    assert settings.log_level == "DEBUG"
    assert settings.port == 9000

def test_invalid_config_handling():
    with pytest.raises(ValidationError):
        Settings(port="not-a-number")

    with pytest.raises(ValidationError):
        Settings(environment="invalid-env")
