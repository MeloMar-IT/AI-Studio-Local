from fastapi.testclient import TestClient

from ltx_worker.main import app
import ltx_worker.api as api

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
    assert data["models"][0]["id"] == "ltx-2.3-distilled"


def test_create_job():
    payload = {
        "prompt": "A beautiful sunset over the ocean",
        "model_id": "ltx-2.3-distilled",
    }
    response = client.post("/generate/text-to-video", json=payload)
    assert response.status_code == 200
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


def test_create_image_to_video_job():
    payload = {
        "prompt": "Make this image move",
        "model_id": "ltx-2.3-distilled",
        "image_path": "/path/to/image.jpg"
    }
    response = client.post("/generate/image-to-video", json=payload)
    assert response.status_code == 200
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
    payload = {
        "prompt": "A beautiful sunset",
        "model_id": "ltx-2.3-distilled",
    }
    response = client.post("/generate/text-to-video", json=payload)
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
    import ltx_worker.api as api
    from ltx_worker.engine.ltx import LTXGenerationEngine
    from ltx_worker.config import settings

    original_engine = api.job_store.engine
    api.job_store.engine = LTXGenerationEngine()

    try:
        payload = {
            "prompt": "Test LTX error",
            "model_id": "ltx-2.3-distilled",
        }
        # In JobStore, the job runs in a task, so we need to wait for it to fail
        response = client.post("/generate/text-to-video", json=payload)
        job_id = response.json()["job_id"]

        # Wait for failure (it should fail immediately as it raises RuntimeError)
        import time
        max_retries = 5
        for _ in range(max_retries):
            time.sleep(0.1)
            status_response = client.get(f"/jobs/{job_id}")
            if status_response.json()["status"] == "failed":
                break

        data = status_response.json()
        assert data["status"] == "failed"
        assert "LTX Generation Engine is not yet fully configured" in data["error"]

    finally:
        api.job_store.engine = original_engine
