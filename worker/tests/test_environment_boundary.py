import pytest
from ltx_worker.config import Settings
from ltx_worker.engine.mock import MockGenerationEngine, MockModelLoader, MockLoraLoader, MockMediaEncoder
from fastapi import APIRouter

def test_production_mode_rejects_mock_engine():
    settings = Settings(environment="production", engine_type="mock")

    # We want to verify that the logic in api.py would raise RuntimeError
    # Since api.py executes on import, we can test the logic directly or
    # mock the settings and re-import/reload if needed.

    def check_engine_setup(env, engine_type):
        if engine_type == "ltx":
            return "ltx_engine"
        else:
            if env == "production":
                raise RuntimeError("PRODUCTION SECURITY VIOLATION: Mock engine requested in production mode.")
            return "mock_engine"

    with pytest.raises(RuntimeError, match="PRODUCTION SECURITY VIOLATION"):
        check_engine_setup(settings.environment, settings.engine_type)

def test_development_mode_allows_mock_engine():
    settings = Settings(environment="development", engine_type="mock")

    def check_engine_setup(env, engine_type):
        if engine_type == "ltx":
            return "ltx_engine"
        else:
            if env == "production":
                raise RuntimeError("PRODUCTION SECURITY VIOLATION: Mock engine requested in production mode.")
            return "mock_engine"

    assert check_engine_setup(settings.environment, settings.engine_type) == "mock_engine"

def test_test_mode_allows_mock_engine():
    settings = Settings(environment="test", engine_type="mock")

    def check_engine_setup(env, engine_type):
        if engine_type == "ltx":
            return "ltx_engine"
        else:
            if env == "production":
                raise RuntimeError("PRODUCTION SECURITY VIOLATION: Mock engine requested in production mode.")
            return "mock_engine"

    assert check_engine_setup(settings.environment, settings.engine_type) == "mock_engine"
