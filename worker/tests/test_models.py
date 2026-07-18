import os
import shutil
import tempfile
import json
from ai_video_worker.utils.models import scan_models, load_model_registry

def test_load_model_registry():
    registry = load_model_registry()
    assert isinstance(registry, list)
    assert len(registry) > 0
    assert any(p["id"] == "ltx-video-2b-distilled" for p in registry)

def test_scan_models_empty():
    with tempfile.TemporaryDirectory() as temp_dir:
        models = scan_models(temp_dir)
        # Should return all registry profiles but with status "missing"
        assert len(models) > 0
        for model in models:
            assert model.status == "missing"
            assert not model.installed

def test_scan_models_installed():
    with tempfile.TemporaryDirectory() as temp_dir:
        # Pick one profile to "install"
        registry = load_model_registry()
        profile = registry[0]
        model_id = profile["id"]
        expected_files = profile["expected_files"]

        # Create model directory
        model_path = os.path.join(temp_dir, model_id)
        os.makedirs(model_path)

        # Create expected files
        for filename in expected_files:
            with open(os.path.join(model_path, filename), "w") as f:
                f.write("test content")

        models = scan_models(temp_dir)

        # Find the installed model in results
        installed_model = next((m for m in models if m.id == model_id), None)
        assert installed_model is not None
        assert installed_model.status == "installed"
        assert installed_model.installed
        assert len(installed_model.missing_files) == 0

def test_scan_models_partial():
    with tempfile.TemporaryDirectory() as temp_dir:
        # Pick a profile with multiple files
        registry = load_model_registry()
        profile = next((p for p in registry if len(p.get("expected_files", [])) > 1), None)
        if not profile:
            return # Skip if no profile has multiple files

        model_id = profile["id"]
        expected_files = profile["expected_files"]

        # Create model directory
        model_path = os.path.join(temp_dir, model_id)
        os.makedirs(model_path)

        # Create only the first file
        with open(os.path.join(model_path, expected_files[0]), "w") as f:
            f.write("test content")

        models = scan_models(temp_dir)

        # Find the model in results
        partial_model = next((m for m in models if m.id == model_id), None)
        assert partial_model is not None
        assert partial_model.status == "partial"
        assert not partial_model.installed
        assert len(partial_model.missing_files) == len(expected_files) - 1
