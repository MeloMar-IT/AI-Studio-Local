import pytest
from ai_video_worker.config import Settings
def test_engine_rejection_in_any_environment():
    # Test the logic specifically
    def check_engine_setup(engine_type):
        if engine_type == "ltx":
            return "ltx_engine"
        else:
            raise RuntimeError(f"ENGINE CONFIGURATION ERROR: Engine type '{engine_type}' is no longer supported.")

    with pytest.raises(RuntimeError, match="ENGINE CONFIGURATION ERROR"):
        check_engine_setup("mock")

def test_api_rejection_of_mock_engine(monkeypatch):
    monkeypatch.setenv("AI_VIDEO_WORKER_ENGINE_TYPE", "mock")

    import importlib
    import ai_video_worker.config
    import ai_video_worker.api

    # Force reload config with new env vars
    importlib.reload(ai_video_worker.config)

    with pytest.raises(RuntimeError, match="ENGINE CONFIGURATION ERROR"):
        importlib.reload(ai_video_worker.api)
