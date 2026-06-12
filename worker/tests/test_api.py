from fastapi.testclient import TestClient

from ltx_worker.main import app

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
