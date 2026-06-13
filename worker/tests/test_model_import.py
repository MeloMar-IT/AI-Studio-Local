import os
import shutil
import pytest
from fastapi.testclient import TestClient
from ltx_worker.main import app
from ltx_worker.config import settings

client = TestClient(app)

@pytest.fixture
def mock_model_dir(tmp_path):
    """Create a mock model directory with expected files."""
    model_dir = tmp_path / "mock-model"
    model_dir.mkdir()

    # Files expected by ltx-2.3-distilled (based on shared/schemas/model_registry.json)
    expected_files = ["ltx_video_2.3_distilled.safetensors", "config.json"]
    for f in expected_files:
        (model_dir / f).write_text("dummy content")

    return model_dir

def test_validate_model_valid(mock_model_dir):
    response = client.post("/models/validate", json={"path": str(mock_model_dir)})
    assert response.status_code == 200
    data = response.json()
    assert data["can_use"] is True
    assert data["matched_profile"]["id"] == "ltx-2.3-distilled"
    assert data["missing_files"] == []

def test_validate_model_invalid_path():
    response = client.post("/models/validate", json={"path": "/non/existent/path"})
    assert response.status_code == 200
    data = response.json()
    assert data["can_use"] is False
    assert "does not exist" in data["message"]

def test_validate_model_missing_files(tmp_path):
    model_dir = tmp_path / "partial-model"
    model_dir.mkdir()
    (model_dir / "config.json").write_text("dummy")

    response = client.post("/models/validate", json={"path": str(model_dir)})
    assert response.status_code == 200
    data = response.json()
    assert data["can_use"] is False
    assert len(data["missing_files"]) > 0
    assert data["matched_profile"]["id"] == "ltx-2.3-distilled"

def test_import_model_copy(mock_model_dir, tmp_path):
    # Setup a temporary models directory for this test
    original_models_dir = settings.models_dir
    test_models_dir = tmp_path / "test_models"
    settings.models_dir = str(test_models_dir)

    try:
        payload = {
            "path": str(mock_model_dir),
            "copy": True,
            "model_id": "test-import-id"
        }
        response = client.post("/models/import", json=payload)
        assert response.status_code == 200
        assert response.json()["success"] is True

        # Verify it exists in target
        assert (test_models_dir / "test-import-id").exists()
        assert (test_models_dir / "test-import-id" / "config.json").exists()
    finally:
        settings.models_dir = original_models_dir

def test_import_model_reference(mock_model_dir, tmp_path):
    # Setup a temporary models directory for this test
    original_models_dir = settings.models_dir
    test_models_dir = tmp_path / "test_models"
    settings.models_dir = str(test_models_dir)

    try:
        payload = {
            "path": str(mock_model_dir),
            "copy": False,
            "model_id": "test-ref-id"
        }
        response = client.post("/models/import", json=payload)
        assert response.status_code == 200
        assert response.json()["success"] is True

        # Verify it's a symlink
        target_path = test_models_dir / "test-ref-id"
        assert target_path.exists()
        assert os.path.islink(str(target_path))
    finally:
        settings.models_dir = original_models_dir
