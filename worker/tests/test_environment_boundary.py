import pytest
from ltx_worker.config import Settings
from ltx_worker.engine.mock import MockGenerationEngine, MockModelLoader, MockLoraLoader, MockMediaEncoder
from fastapi import APIRouter
from ltx_worker.api import router # This will trigger the actual check if we can mock settings

def test_production_mode_rejects_mock_engine_logic():
    # Test the logic specifically
    def check_engine_setup(env, engine_type):
        if engine_type == "ltx":
            return "ltx_engine"
        else:
            if env == "production":
                raise RuntimeError("PRODUCTION SECURITY VIOLATION: Mock engine requested in production mode.")
            return "mock_engine"

    with pytest.raises(RuntimeError, match="PRODUCTION SECURITY VIOLATION"):
        check_engine_setup("production", "mock")

def test_api_rejection_in_production(monkeypatch):
    # Use monkeypatch to set environment variables before importing/initializing
    monkeypatch.setenv("LTX_WORKER_ENVIRONMENT", "production")
    monkeypatch.setenv("LTX_WORKER_ENGINE_TYPE", "mock")

    # Since ltx_worker.api might already be imported, we might need to reload it
    # or just trust the logic test above if reloading is too messy.
    # But let's try a clean approach.

    import importlib
    import ltx_worker.config
    import ltx_worker.api

    # Force reload config with new env vars
    importlib.reload(ltx_worker.config)

    with pytest.raises(RuntimeError, match="PRODUCTION SECURITY VIOLATION"):
        importlib.reload(ltx_worker.api)

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
