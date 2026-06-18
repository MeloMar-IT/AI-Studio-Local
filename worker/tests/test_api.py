import os
import json
from datetime import datetime
from unittest.mock import patch
from fastapi.testclient import TestClient

from ai_video_worker.main import app
import ai_video_worker.api as api

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert "version" in data
    assert "uptime" in data


def test_hardware():
    response = client.get("/hardware")
    assert response.status_code == 200
    data = response.json()
    assert "chip" in data
    assert "total_memory_gb" in data
    assert "os_version" in data


def test_models():
    response = client.get("/models")
    assert response.status_code == 200
    data = response.json()
    assert "models" in data
    assert len(data["models"]) > 0
    assert data["models"][0]["id"] == "ltx-video-2b-v0.9"


def test_create_job():
    # Mock scan_models so it doesn't fail on model existence check
    with patch("ai_video_worker.api.scan_models") as mock_scan:
        from ai_video_worker.schemas.api import ModelProfile
        mock_scan.return_value = [
            ModelProfile(
                id="ltx-video-2b-v0.9",
                name="LTX-Video 2B v0.9",
                description="Production quality base model",
                family="LTX-Video",
                version="0.9",
                expected_files=[],
                memory_requirement_gb=0,
                supported_modes=["text-to-video", "image-to-video"],
                recommended_hardware="Any",
                installed=True,
                missing_files=[]
            )
        ]

        payload = {
            "prompt": "A beautiful sunset over the ocean",
            "model_id": "ltx-video-2b-v0.9",
        }
        response = client.post("/generate/text-to-video", json=payload)
        assert response.status_code == 200, f"Response: {response.json()}"
        data = response.json()
        assert "job_id" in data
        assert data["status"] == "preparing_prompt"

        job_id = data["job_id"]
        response = client.get(f"/jobs/{job_id}")
        assert response.status_code == 200
        assert response.json()["job_id"] == job_id


def test_job_not_found():
    response = client.get("/jobs/non-existent-id")
    assert response.status_code == 404


def test_download_model():
    # Mock download_model in utils.models
    with patch("ai_video_worker.api.download_model") as mock_download:
        mock_download.return_value = {
            "success": True,
            "message": "Started downloading ltx-video-2b-v0.9",
            "job_id": "test-job-id",
            "model_id": "ltx-video-2b-v0.9"
        }

        response = client.post("/models/download", json={"model_id": "ltx-video-2b-v0.9"})
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["job_id"] == "test-job-id"
        mock_download.assert_called_once()


def test_delete_model():
    with patch("ai_video_worker.api.delete_model") as mock_delete:
        mock_delete.return_value = {
            "success": True,
            "message": "Successfully deleted model: ltx-video-2b-v0.9"
        }

        response = client.delete("/models/ltx-video-2b-v0.9")
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        mock_delete.assert_called_once()


def test_job_events_sse():
    # Mock scan_models for job creation
    with patch("ai_video_worker.api.scan_models") as mock_scan:
        from ai_video_worker.schemas.api import ModelProfile
        mock_scan.return_value = [
            ModelProfile(
                id="ltx-video-2b-v0.9",
                name="LTX-Video 2B v0.9",
                description="Production quality base model",
                family="LTX-Video",
                version="0.9",
                expected_files=[],
                memory_requirement_gb=0,
                supported_modes=["text-to-video"],
                recommended_hardware="Any",
                installed=True,
                missing_files=[]
            )
        ]

        payload = {
            "prompt": "Test SSE events",
            "model_id": "ltx-video-2b-v0.9",
        }
        create_resp = client.post("/generate/text-to-video", json=payload)
        job_id = create_resp.json()["job_id"]

        # Test the SSE endpoint
        response = client.get(f"/jobs/{job_id}/events")
        assert response.status_code == 200
        assert "text/event-stream" in response.headers["content-type"]

        # Read first few lines from the response text
        lines = [line for line in response.text.split("\n") if line]

        assert any("heartbeat" in l for l in lines)
        assert any("data: " in l for l in lines)

def test_download_model_logic():
    # Test download_model without mocking the whole thing, just the registry and download
    with patch("ai_video_worker.utils.models.load_model_registry") as mock_registry, \
         patch("ai_video_worker.utils.models.requests.get") as mock_get:

        mock_registry.return_value = [{
            "id": "test-model",
            "name": "Test Model",
            "description": "Desc",
            "family": "LTX-Video",
            "download_urls": {"file.bin": "http://example.com/file.bin"},
            "expected_files": ["file.bin"]
        }]

        # Mock background tasks
        from fastapi import BackgroundTasks
        bg = BackgroundTasks()

        from ai_video_worker.utils.models import download_model
        result = download_model("test-model", bg)

        assert result["success"] is True
        assert "job_id" in result

def test_job_store_update_status(tmp_path):
    from ai_video_worker.jobs.store import JobStore
    from ai_video_worker.engine.output import OutputManager
    from ai_video_worker.schemas.api import JobStatus
    from unittest.mock import MagicMock

    output_manager = OutputManager(tmp_path)
    engine = MagicMock()
    store = JobStore(engine, output_manager)

    job_id = "test-job"
    now = datetime.now()
    store.jobs[job_id] = JobStatus(
        job_id=job_id,
        status="pending",
        progress=0.0,
        message="Pending...",
        created_at=now,
        updated_at=now
    )

    store.update_job_status(job_id, "downloading", 0.5, "Downloading...")

    assert store.jobs[job_id].status == "downloading"
    assert store.jobs[job_id].progress == 0.5
    assert store.jobs[job_id].message == "Downloading..."

    # Check if metadata was saved
    metadata_path = output_manager.get_metadata_path(job_id)
    assert metadata_path.exists()
    with open(metadata_path, "r") as f:
        metadata = json.load(f)
    assert metadata["status"] == "downloading"
    assert metadata["progress"] == 0.5


def test_create_image_to_video_job(tmp_path):
    # Create a dummy image
    img_path = tmp_path / "test.jpg"
    img_path.write_bytes(b"fake data")

    with patch("ai_video_worker.api.scan_models") as mock_scan:
        from ai_video_worker.schemas.api import ModelProfile
        mock_scan.return_value = [
            ModelProfile(
                id="ltx-2.3-distilled",
                name="LTX-2.3 Distilled",
                description="Fast draft generation",
                family="LTX-Video",
                version="2.3",
                expected_files=[],
                memory_requirement_gb=0,
                supported_modes=["text-to-video", "image-to-video"],
                recommended_hardware="Any",
                installed=True,
                missing_files=[]
            )
        ]

        payload = {
            "prompt": "Make this image move",
            "model_id": "ltx-2.3-distilled",
            "image_path": str(img_path)
        }
        response = client.post("/generate/image-to-video", json=payload)
        assert response.status_code == 200, f"Response: {response.json()}"
        data = response.json()
        assert "job_id" in data

        job_id = data["job_id"]
        # Check that it started
        response = client.get(f"/jobs/{job_id}")
        assert response.status_code == 200

def test_image_to_video_missing_image():
    payload = {
        "prompt": "Make this image move",
        "model_id": "ltx-2.3-distilled"
    }
    response = client.post("/generate/image-to-video", json=payload)
    assert response.status_code == 400
    # Updated to check structured error
    data = response.json()
    assert "error" in data
    assert data["error"]["code"] == "http_400"
    assert "image_path is required" in data["error"]["message"]


def test_structured_error_404():
    response = client.get("/jobs/non-existent-id")
    assert response.status_code == 404
    data = response.json()
    assert "error" in data
    assert data["error"]["code"] == "http_404"
    assert "Job not found" in data["error"]["message"]


def test_cancel_job():
    with patch("ai_video_worker.api.scan_models") as mock_scan:
        from ai_video_worker.schemas.api import ModelProfile
        mock_scan.return_value = [
            ModelProfile(
                id="ltx-2.3-distilled",
                name="LTX-2.3 Distilled",
                description="Fast draft generation",
                family="LTX-Video",
                version="2.3",
                expected_files=[],
                memory_requirement_gb=0,
                supported_modes=["text-to-video", "image-to-video"],
                recommended_hardware="Any",
                installed=True,
                missing_files=[]
            )
        ]

        payload = {
            "prompt": "A beautiful sunset",
            "model_id": "ltx-2.3-distilled",
        }
        response = client.post("/generate/text-to-video", json=payload)
        assert response.status_code == 200
        job_id = response.json()["job_id"]

        cancel_response = client.post(f"/jobs/{job_id}/cancel")
        assert cancel_response.status_code == 200

        # Wait for status to update
        import time
        time.sleep(0.1)

        # Verify status is terminal (cancelled, completed, or failed)
        status_response = client.get(f"/jobs/{job_id}")
        assert status_response.json()["status"] in ["cancelled", "completed", "failed"]


def test_ltx_engine_explicit_error():
    # Force LTX engine
    import ai_video_worker.api as api
    from ai_video_worker.engine.ltx import LTXGenerationEngine
    from ai_video_worker.config import settings

    original_engine = api.job_store.engine
    # Use a dummy adapter that fails immediately
    from ai_video_worker.engine.adapter import LTXAdapter
    class FailingAdapter(LTXAdapter):
        def capabilities(self): return ["text-to-video"]
        async def load_model(self, m): pass
        async def unload_model(self, m): pass
        async def generate_text_to_video(self, *args, **kwargs):
            raise RuntimeError("Explicit LTX Error")
        async def generate_image_to_video(self, *args, **kwargs): pass
        async def generate_audio_to_video(self, *args, **kwargs): pass
        async def generate_retake(self, *args, **kwargs): pass

    api.job_store.engine = LTXGenerationEngine(adapter=FailingAdapter())

    try:
        with patch("ai_video_worker.api.scan_models") as mock_scan:
            from ai_video_worker.schemas.api import ModelProfile
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

            payload = {
                "prompt": "Test LTX error",
                "model_id": "ltx-2.3-distilled",
            }
            response = client.post("/generate/text-to-video", json=payload)
            assert response.status_code == 200
            job_id = response.json()["job_id"]

            # Wait for failure
            import time
            for _ in range(20):
                time.sleep(0.1)
                status_response = client.get(f"/jobs/{job_id}")
                if status_response.json()["status"] == "failed":
                    break

            data = status_response.json()
            assert data["status"] == "failed"
            assert "Explicit LTX Error" in data["error"]

    finally:
        api.job_store.engine = original_engine

def test_audio_to_video_unsupported():
    payload = {
        "prompt": "Sync with this music",
        "model_id": "ltx-2.3-distilled",
        "audio_path": "/path/to/audio.mp3"
    }
    response = client.post("/generate/audio-to-video", json=payload)
    assert response.status_code == 400
    data = response.json()
    assert "error" in data
    assert data["error"]["code"] == "unsupported_capability"
    assert "audio-to-video" in data["error"]["message"]

def test_retake_unsupported():
    payload = {
        "prompt": "Retake this part",
        "model_id": "ltx-2.3-distilled"
    }
    response = client.post("/generate/retake", json=payload)
    assert response.status_code == 400
    data = response.json()
    assert "error" in data
    assert data["error"]["code"] == "unsupported_capability"
    assert "retake" in data["error"]["message"]
