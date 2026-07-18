import os
import json
import shutil
import requests
from typing import List, Optional
from ltx_worker.schemas.api import ModelProfile, ProgressEvent
from ltx_worker.config import settings
from datetime import datetime
import uuid

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

def download_model(model_id: str, background_tasks):
    """Downloads a model by ID."""
    registry = load_model_registry()
    model_data = next((m for m in registry if m["id"] == model_id), None)

    if not model_data:
        return {"success": False, "message": f"Model '{model_id}' not found in registry."}

    download_urls = model_data.get("download_urls")
    if not download_urls:
        return {"success": False, "message": f"No download URLs found for model '{model_id}'."}

    # Create model directory
    model_dir = os.path.join(settings.models_dir, model_id)
    os.makedirs(model_dir, exist_ok=True)

    job_id = str(uuid.uuid4())

    def download_task():
        try:
            total_files = len(download_urls)
            for i, (filename, url) in enumerate(download_urls.items()):
                file_path = os.path.join(model_dir, filename)

                # Update progress
                logger.info(f"Downloading {filename} from {url}...")

                response = requests.get(url, stream=True)
                response.raise_for_status()

                total_size = int(response.headers.get('content-length', 0))
                downloaded_size = 0

                with open(file_path, "wb") as f:
                    for chunk in response.iter_content(chunk_size=8192):
                        if chunk:
                            f.write(chunk)
                            downloaded_size += len(chunk)
                            # Could emit progress events here if we had a websocket or event stream

                logger.info(f"Finished downloading {filename}")

            logger.info(f"Successfully downloaded all files for {model_id}")
        except Exception as e:
            logger.error(f"Failed to download model {model_id}: {str(e)}")
            # Cleanup on failure? Maybe not, to allow resuming later if we implemented it

    background_tasks.add_task(download_task)

    return {
        "success": True,
        "message": f"Started downloading {model_id}",
        "job_id": job_id,
        "model_id": model_id
    }

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
            download_urls=data.get("download_urls"),
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

def validate_model_folder(path: str) -> dict:
    """Validate a folder against the model registry."""
    if not os.path.exists(path):
        return {
            "can_use": False,
            "message": f"Path does not exist: {path}",
            "missing_files": [],
            "warnings": [],
            "matched_profile": None
        }

    if not os.path.isdir(path):
        return {
            "can_use": False,
            "message": f"Path is not a directory: {path}",
            "missing_files": [],
            "warnings": [],
            "matched_profile": None
        }

    profiles_data = load_model_registry()
    files_in_dir = os.listdir(path)

    best_match = None
    min_missing = float('inf')
    best_missing_files = []

    for data in profiles_data:
        expected_files = data.get("expected_files", [])
        missing_files = [f for f in expected_files if f not in files_in_dir]

        # If we found a perfect match or a better partial match
        if len(missing_files) < min_missing:
            min_missing = len(missing_files)
            best_missing_files = missing_files

            # Create ModelProfile for the match
            model_id = data["id"]
            best_match = ModelProfile(
                id=model_id,
                name=data["name"],
                description=data["description"],
                family=data["family"],
                version=data.get("version"),
                expected_files=expected_files,
                download_urls=data.get("download_urls"),
                memory_requirement_gb=data.get("memory_requirement_gb"),
                supported_modes=data.get("supported_modes", []),
                recommended_hardware=data.get("recommended_hardware"),
                local_path=path,
                installed=len(missing_files) == 0,
                recommended=model_id == settings.default_model_id,
                missing_files=missing_files,
                status="installed" if len(missing_files) == 0 else "partial"
            )

    if best_match:
        if min_missing == 0:
            return {
                "can_use": True,
                "message": f"Valid {best_match.name} model found.",
                "missing_files": [],
                "warnings": [],
                "matched_profile": best_match
            }
        else:
            return {
                "can_use": False,
                "message": f"Folder matches {best_match.name} but is missing {min_missing} files.",
                "missing_files": best_missing_files,
                "warnings": [f"Missing files for {best_match.name}: {', '.join(best_missing_files)}"],
                "matched_profile": best_match
            }

    return {
        "can_use": False,
        "message": "No matching model profile found in registry.",
        "missing_files": [],
        "warnings": ["Unknown model structure."],
        "matched_profile": None
    }

def import_model(path: str, model_id: str, copy: bool = True) -> dict:
    """Import a model by copying or symlinking it into the models directory."""
    if not os.path.exists(path):
        return {"success": False, "message": f"Source path does not exist: {path}"}

    models_dir = settings.models_dir
    if not os.path.exists(models_dir):
        os.makedirs(models_dir, exist_ok=True)

    target_path = os.path.join(models_dir, model_id)

    if os.path.exists(target_path):
        return {"success": False, "message": f"Model {model_id} already exists in {models_dir}"}

    try:
        if copy:
            # For directories, use copytree
            if os.path.isdir(path):
                shutil.copytree(path, target_path)
            else:
                shutil.copy2(path, target_path)
            message = f"Model {model_id} copied to {target_path}"
        else:
            # Create a symbolic link
            os.symlink(os.path.abspath(path), target_path)
            message = f"Model {model_id} symlinked to {target_path}"

        return {"success": True, "message": message, "target_path": target_path}
    except Exception as e:
        return {"success": False, "message": f"Import failed: {str(e)}"}
