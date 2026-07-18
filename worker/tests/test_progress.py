import json
import time
import asyncio
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
from ai_video_worker.main import app
from ai_video_worker.schemas.api import ModelProfile
from ai_video_worker.engine.adapter import LTXAdapter

client = TestClient(app)

class FastCancelAdapter(LTXAdapter):
    def capabilities(self): return ["text-to-video"]
    async def load_model(self, model_profile): return None
    async def unload_model(self, model_id): pass
    async def generate_text_to_video(self, request, output_path, progress_callback=None, cancellation_token=None):
        # Loop until cancelled
        while cancellation_token and not cancellation_token.is_cancelled:
            await asyncio.sleep(0.01)
        if cancellation_token and cancellation_token.is_cancelled:
            raise asyncio.CancelledError()
        return output_path
    async def generate_image_to_video(self, *args, **kwargs): return ""
    async def generate_audio_to_video(self, *args, **kwargs): return ""
    async def generate_retake(self, *args, **kwargs): return ""

def test_cancellation_propagation():
    from ai_video_worker.engine.ltx import LTXGenerationEngine
    test_engine = LTXGenerationEngine(adapter=FastCancelAdapter())

    # We need to ensure the worker uses our test_engine.
    # The ai_video_worker.main app might have already initialized the engine from api.py.
    # In ai_video_worker.api, the 'engine' variable is used to initialize JobStore.
    from ai_video_worker.api import store
    original_engine = store.job_store.engine
    store.job_store.engine = test_engine

    try:
        with patch("ai_video_worker.api.scan_models") as mock_scan:
            mock_scan.return_value = [
                ModelProfile(
                    id="ltx-2.3-distilled",
                    name="LTX-2.3 Distilled",
                    description="Fast draft generation",
                    family="LTX-Video",
                    version="2.3",
                    expected_files=[],
                    memory_requirement_gb=0,
                    supported_modes=["text-to-video"],
                    recommended_hardware="Any",
                    installed=True,
                    missing_files=[]
                )
            ]

            # 1. Create a job
            payload = {
                "prompt": "Cancel test",
                "model_id": "ltx-2.3-distilled",
            }
            response = client.post("/generate/text-to-video", json=payload)
            job_id = response.json()["job_id"]

            # 2. Cancel the job
            response = client.post(f"/jobs/{job_id}/cancel")
            assert response.status_code == 200
            # Give it a tiny bit of time to propagate
            time.sleep(0.1)

            # 3. Verify status in job store
            response = client.get(f"/jobs/{job_id}")
            assert response.status_code == 200
            assert response.json()["status"] == "cancelled"
    finally:
        store.job_store.engine = original_engine
