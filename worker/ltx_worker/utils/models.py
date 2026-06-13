import os
import json
from typing import List, Optional
from ltx_worker.schemas.api import ModelProfile
from ltx_worker.config import settings

def load_model_registry() -> List[dict]:
    """Load the model registry from the shared schemas directory."""
    # Try to find the registry file. It might be relative to the worker root or project root.
    potential_paths = [
        "../shared/schemas/model_registry.json",
        "shared/schemas/model_registry.json",
        os.path.join(os.path.dirname(__file__), "../../../shared/schemas/model_registry.json")
    ]

    for path in potential_paths:
        if os.path.exists(path):
            with open(path, "r") as f:
                data = json.load(f)
                return data.get("profiles", [])

    # Fallback to a minimal registry if file not found (though it should be there)
    return []

def scan_models(models_dir: str) -> List[ModelProfile]:
    """Scan the models directory and match against the registry."""
    profiles_data = load_model_registry()
    results = []

    # Ensure models_dir exists
    if not os.path.exists(models_dir):
        os.makedirs(models_dir, exist_ok=True)

    for data in profiles_data:
        model_id = data["id"]
        expected_files = data.get("expected_files", [])

        # Model path is models_dir / model_id
        model_path = os.path.join(models_dir, model_id)

        missing_files = []
        installed_files = []

        if os.path.exists(model_path) and os.path.isdir(model_path):
            for filename in expected_files:
                file_path = os.path.join(model_path, filename)
                if not os.path.exists(file_path):
                    missing_files.append(filename)
                else:
                    installed_files.append(filename)
        else:
            missing_files = expected_files

        # Determine status
        if not missing_files:
            status = "installed"
            installed = True
        elif len(installed_files) > 0:
            status = "partial"
            installed = False
        else:
            status = "missing"
            installed = False

        # Create ModelProfile object
        profile = ModelProfile(
            id=model_id,
            name=data["name"],
            description=data["description"],
            family=data["family"],
            version=data.get("version"),
            expected_files=expected_files,
            memory_requirement_gb=data.get("memory_requirement_gb"),
            supported_modes=data.get("supported_modes", []),
            recommended_hardware=data.get("recommended_hardware"),
            local_path=model_path if installed or status == "partial" else None,
            installed=installed,
            recommended=model_id == settings.default_model_id,
            missing_files=missing_files,
            status=status
        )
        results.append(profile)

    return results
