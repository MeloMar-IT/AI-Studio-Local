import pytest
from unittest.mock import patch
from fastapi.testclient import TestClient
from ltx_worker.main import app

client = TestClient(app)

def test_error_response_structure():
    # Trigger 404
    response = client.get("/jobs/non-existent-id")
    assert response.status_code == 404
    data = response.json()
    assert "error" in data
    assert "code" in data["error"]
    assert "message" in data["error"]
    assert data["error"]["code"] == "http_404"

def test_model_not_found_error():
    from unittest.mock import patch
    with patch("ltx_worker.api.scan_models") as mock_scan:
        mock_scan.return_value = [] # No models

        response = client.post("/generate/text-to-video", json={
            "prompt": "Test",
            "model_id": "non-existent-model"
        })
        assert response.status_code == 400
        data = response.json()
        assert data["error"]["code"] == "model_not_found"
        assert "action" in data["error"]

def test_unsupported_mode_error():
    from unittest.mock import patch
    from ltx_worker.schemas.api import ModelProfile

    with patch("ltx_worker.api.scan_models") as mock_scan:
        mock_scan.return_value = [
            ModelProfile(
                id="text-only-model",
                name="Text Only",
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

        response = client.post("/generate/image-to-video", json={
            "prompt": "Test",
            "model_id": "text-only-model",
            "image_path": "test.png" # Path check happens before mode check? No, engine capabilities first then mode check.
        })
        # Note: image-to-video check in api.py:
        # 1. engine capabilities check
        # 2. image_path presence check
        # 3. _validate_image_path (exists)
        # 4. _validate_model_for_generation (mode check)

        # We need a real existing file for _validate_image_path to pass
        import os
        import tempfile
        with tempfile.NamedTemporaryFile(suffix=".png") as tmp:
            response = client.post("/generate/image-to-video", json={
                "prompt": "Test",
                "model_id": "text-only-model",
                "image_path": tmp.name
            })
            assert response.status_code == 400
            data = response.json()
            assert data["error"]["code"] == "unsupported_mode"
