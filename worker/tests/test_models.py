import os
import shutil
import tempfile
import json
from ai_video_worker.utils.models import scan_models, load_model_registry, is_model_installed
from ai_video_worker.config import settings
from unittest.mock import patch

def test_is_model_installed():
    with tempfile.TemporaryDirectory() as temp_dir:
        # Patch settings.models_dir to use our temp dir
        with patch.object(settings, 'models_dir', temp_dir):
            registry = load_model_registry()
            profile = registry[0]
            model_id = profile["id"]
            expected_files = profile["expected_files"]

            # Initially not installed
            assert not is_model_installed(model_id)

            # Create model directory and files
            model_path = os.path.join(temp_dir, model_id)
            os.makedirs(model_path)
            for filename in expected_files:
                with open(os.path.join(model_path, filename), "w") as f:
                    f.write("test content")

            # Now it should be installed
            assert is_model_installed(model_id)

            # Remove one file -> partial -> not installed
            os.remove(os.path.join(model_path, expected_files[0]))
            assert not is_model_installed(model_id)

def test_scan_models_filtering():
    with tempfile.TemporaryDirectory() as temp_dir:
        # Patch settings.models_dir to use our temp dir
        with patch.object(settings, 'models_dir', temp_dir):
            registry = load_model_registry()
            profile = registry[0]
            model_id = profile["id"]
            expected_files = profile["expected_files"]

            # Initially no models should be returned as none are installed
            assert len(scan_models(temp_dir)) == 0

            # Create model directory and files for one model
            model_path = os.path.join(temp_dir, model_id)
            os.makedirs(model_path)
            for filename in expected_files:
                with open(os.path.join(model_path, filename), "w") as f:
                    f.write("test content")

            # Now scan_models should return this one model
            models = scan_models(temp_dir)
            assert len(models) == 1
            assert models[0].id == model_id
            assert models[0].installed

def test_load_model_registry():
    registry = load_model_registry()
    assert isinstance(registry, list)
    assert len(registry) > 0
    assert any(p["id"] == "ltx-video-2b-distilled" for p in registry)

def test_scan_models_empty():
    with tempfile.TemporaryDirectory() as temp_dir:
        models = scan_models(temp_dir)
        # Should now return 0 because none are installed
        assert len(models) == 0

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

        # Now scan_models should NOT return this model because it's only partially installed
        models = scan_models(temp_dir)
        partial_model = next((m for m in models if m.id == model_id), None)
        assert partial_model is None
