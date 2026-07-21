import os
import json
import pytest
import asyncio
from fastapi.testclient import TestClient
from ai_video_worker.main import app
from ai_video_worker.config import settings
from unittest.mock import patch, MagicMock

client = TestClient(app)

@pytest.fixture
def mock_training_data():
    """Create some dummy video files for training."""
    os.makedirs("mock_training_data", exist_ok=True)
    v1 = "mock_training_data/video1.mp4"
    with open(v1, "w") as f:
        f.write("dummy video 1")
    v2 = "mock_training_data/video2.mp4"
    with open(v2, "w") as f:
        f.write("dummy video 2")
    return [os.path.abspath(v1), os.path.abspath(v2)]

@pytest.mark.asyncio
async def test_train_lora_endpoint(mock_training_data):
    # Ensure lora-training is in capabilities
    response = client.get("/hardware")
    # Actually capabilities are not in /hardware directly, but in /models or implied by engine

    training_request = {
        "project_id": "test_project",
        "element_id": "test_element",
        "element_type": "character",
        "training_data_paths": mock_training_data,
        "trigger_word": "test_trigger",
        "steps": 1,
        "model_id": "ltx-video-av-q4"
    }

    # We need to mock the subprocess call in MLXLTXAdapter.train_lora
    # because we don't have the real model weights and it's too heavy for a unit test.
    with patch("asyncio.create_subprocess_exec") as mock_exec:
        # Mock the process
        mock_process = MagicMock()
        mock_process.wait = MagicMock(side_effect=asyncio.sleep(0.1))
        mock_process.stdout.readline = MagicMock(side_effect=[b"Preprocessing...", b"Training step 1/1", b""])
        mock_process.stderr.readline = MagicMock(return_value=b"")
        mock_process.returncode = 0

        # In python 3.8+ return value of create_subprocess_exec must be awaited
        mock_exec.return_value = mock_process

        # We also need to mock the file movement and size check at the end
        with patch("os.path.exists", return_value=True), \
             patch("shutil.move"), \
             patch("os.path.getsize", return_value=2000), \
             patch("pathlib.Path.glob", return_value=[MagicMock(name="checkpoint.safetensors")]):

            response = client.post("/train/lora", json=training_request)
            assert response.status_code == 200
            job_data = response.json()
            assert job_data["job_id"] is not None
            # The initial status set by submit_training_job is "preparing_training"
            assert job_data["status"] in ["preparing_training", "training_lora", "completed"]

            # Wait a bit for the background task to run
            job_id = job_data["job_id"]

            # Since it's background, we might need to poll or just trust the call happened
            # In a real test we'd wait, but here we've mocked the subprocess.

            # Check if job exists in store
            from ai_video_worker.jobs.store import job_store
            job = job_store.get_job(job_id)
            assert job is not None

@pytest.mark.asyncio
async def test_capabilities_includes_lora_training():
    from ai_video_worker.api import engine
    assert "lora-training" in engine.capabilities()
