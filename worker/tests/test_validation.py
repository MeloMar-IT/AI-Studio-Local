import pytest
from unittest.mock import patch
from fastapi.testclient import TestClient
from ltx_worker.main import app

client = TestClient(app)

def test_generation_request_validation():
    # Missing required field 'prompt'
    response = client.post("/generate/text-to-video", json={
        "model_id": "ltx-2.3-distilled"
    })
    assert response.status_code == 422
    assert "error" in response.json()
    assert response.json()["error"]["code"] == "http_422"

    # Missing required field 'model_id'
    response = client.post("/generate/text-to-video", json={
        "prompt": "A beautiful sunset"
    })
    assert response.status_code == 422

    # Valid request (with mocked scan_models)
    from unittest.mock import patch
    from ltx_worker.schemas.api import ModelProfile

    with patch("ltx_worker.api.scan_models") as mock_scan:
        mock_scan.return_value = [
            ModelProfile(
                id="test-model",
                name="Test Model",
                description="Test",
                family="Test",
                version="1.0",
                expected_files=[],
                memory_requirement_gb=0,
                supported_modes=["text-to-video"],
                recommended_hardware="Any",
                installed=True,
                missing_files=[]
            )
        ]
        response = client.post("/generate/text-to-video", json={
            "prompt": "A beautiful sunset",
            "model_id": "test-model"
        })
        assert response.status_code == 200
        assert "job_id" in response.json()

def test_image_to_video_validation():
    # image_to_video requires image_path
    from unittest.mock import patch
    from ltx_worker.schemas.api import ModelProfile

    with patch("ltx_worker.api.scan_models") as mock_scan:
        mock_scan.return_value = [
            ModelProfile(
                id="test-model",
                name="Test Model",
                description="Test",
                family="Test",
                version="1.0",
                expected_files=[],
                memory_requirement_gb=0,
                supported_modes=["image-to-video"],
                recommended_hardware="Any",
                installed=True,
                missing_files=[]
            )
        ]

        # Missing image_path
        response = client.post("/generate/image-to-video", json={
            "prompt": "Make it move",
            "model_id": "test-model"
        })
        assert response.status_code == 400
        assert response.json()["error"]["code"] == "http_400"

        # Invalid image_path (not found)
        response = client.post("/generate/image-to-video", json={
            "prompt": "Make it move",
            "model_id": "test-model",
            "image_path": "/non/existent/path.png"
        })
        assert response.status_code == 400
        assert response.json()["error"]["code"] == "image_not_found"
