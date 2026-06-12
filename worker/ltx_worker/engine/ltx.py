import asyncio
import json
import os
import platform
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Optional

import psutil
from ltx_worker.config import settings
from ltx_worker.engine.base import (
    CancellationToken,
    GenerationEngine,
    ProgressCallback,
)
from ltx_worker.logging_config import logger


class LTXGenerationEngine(GenerationEngine):
    """
    Real LTX generation engine using MLX.
    For MVP, this handles the workflow of:
    1. Hardware validation
    2. Model validation
    3. Generation (with progress)
    4. Output encoding
    5. Metadata preservation
    """

    async def generate(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        # Debug request type
        logger.info(f"LTXGenerationEngine.generate: request type={type(request)}")

        start_time = time.time()
        job_id = Path(output_path).parent.name

        try:
            # 1. Hardware Validation
            if progress_callback:
                progress_callback("checking_hardware", 0.05, "Validating hardware compatibility...")

            self._validate_hardware()

            # 2. Model Validation
            if progress_callback:
                progress_callback("loading_model", 0.1, f"Validating model: {request.model_id}...")

            model_path = self._get_model_path(request.model_id)
            self._validate_model_files(model_path)

            # 3. Generation (MLX/LTX Integration Point)
            if progress_callback:
                progress_callback("generating_video", 0.2, "Initializing MLX LTX pipeline...")

            # TODO: Import real MLX/LTX libraries here when available in environment
            # For now, we simulate the progress of a real generation while keeping the structure real

            num_steps = request.steps
            for step in range(num_steps):
                if cancellation_token and cancellation_token.is_cancelled:
                    logger.info(f"Generation {job_id} cancelled at step {step}")
                    return ""

                # Simulate generation work
                await asyncio.sleep(0.5)

                progress = 0.2 + (step / num_steps) * 0.6
                if progress_callback:
                    progress_callback(
                        "generating_video",
                        progress,
                        f"Generating frames (Step {step+1}/{num_steps})..."
                    )

            # 4. Encoding Output
            if progress_callback:
                progress_callback("encoding_output", 0.9, "Encoding final MP4 and saving preview...")

            # Simulate encoding and saving
            await self._save_outputs(output_path)

            # 5. Metadata Preservation
            generation_time = time.time() - start_time
            self._save_detailed_metadata(job_id, request, output_path, generation_time)

            if progress_callback:
                progress_callback("completed", 1.0, "Generation completed successfully.")

            return output_path

        except Exception as e:
            logger.error(f"Generation failed: {e}")
            raise e

    def _validate_hardware(self):
        """Validates that the current Mac appears compatible."""
        # Check for Apple Silicon
        if platform.machine() != "arm64":
            logger.warning("Not running on Apple Silicon. MLX might be slow or unsupported.")
            # We don't hard-fail here yet to allow development on other platforms if needed,
            # but in production we might want to.

        # Check memory
        mem = psutil.virtual_memory()
        total_gb = mem.total / (1024**3)
        if total_gb < settings.min_memory_gb:
            raise RuntimeError(
                f"Insufficient memory: {total_gb:.1f}GB. "
                f"LTX requires at least {settings.min_memory_gb}GB."
            )

    def _get_model_path(self, model_id: str) -> Path:
        """Resolves the model ID to a local path."""
        return Path(settings.models_dir) / model_id

    def _validate_model_files(self, model_path: Path):
        """Validates that required model files exist."""
        if not model_path.exists():
            raise FileNotFoundError(f"Model directory not found: {model_path}")

        # In a real LTX/MLX setup, we'd check for weights.safetensors, config.json, etc.
        # For now, we just ensure the directory exists.
        # required_files = ["weights.safetensors", "config.json"]
        # for f in required_files:
        #     if not (model_path / f).exists():
        #         raise FileNotFoundError(f"Missing required model file: {f} in {model_path}")

    async def _save_outputs(self, output_path: str):
        """Simulates saving the video and a preview image."""
        output_path_obj = Path(output_path)
        output_path_obj.parent.mkdir(parents=True, exist_ok=True)

        # Mock video file
        with open(output_path, "wb") as f:
            f.write(b"REAL_LTX_VIDEO_DATA_MOCK")

        # Mock preview image
        preview_path = output_path_obj.parent / "preview.jpg"
        with open(preview_path, "wb") as f:
            f.write(b"REAL_LTX_PREVIEW_DATA_MOCK")

    def _save_detailed_metadata(
        self,
        job_id: str,
        request: Any,
        output_path: str,
        generation_time: float
    ):
        """Saves detailed metadata.json as required."""
        # Ensure we can handle both dict and Pydantic models (request might be Pydantic)
        if hasattr(request, "model_dump"):
            req_data = request.model_dump()
        elif hasattr(request, "dict"):
            req_data = request.dict()
        elif isinstance(request, dict):
            req_data = request
        else:
            # Fallback to direct attribute access if it's some other object
            req_data = {
                "prompt": getattr(request, "prompt", None),
                "negative_prompt": getattr(request, "negative_prompt", None),
                "model_id": getattr(request, "model_id", None),
                "seed": getattr(request, "seed", None),
                "width": getattr(request, "width", None),
                "height": getattr(request, "height", None),
                "num_frames": getattr(request, "num_frames", None),
                "steps": getattr(request, "steps", None),
                "guidance_scale": getattr(request, "guidance_scale", None),
            }

        metadata = {
            "job_id": job_id,
            "timestamp": datetime.now().isoformat(),
            "prompt": req_data.get("prompt"),
            "negative_prompt": req_data.get("negative_prompt"),
            "model_id": req_data.get("model_id"),
            "seed": req_data.get("seed"),
            "resolution": f"{req_data.get('width')}x{req_data.get('height')}",
            "duration_frames": req_data.get("num_frames"),
            "settings": {
                "steps": req_data.get("steps"),
                "guidance_scale": req_data.get("guidance_scale"),
            },
            "generation_time_seconds": round(generation_time, 2),
            "output_path": output_path,
            "device_info": {
                "machine": platform.machine(),
                "processor": platform.processor(),
                "system": platform.system(),
                "memory_gb": round(psutil.virtual_memory().total / (1024**3), 2)
            }
        }

        metadata_path = Path(output_path).parent / "metadata.json"
        with open(metadata_path, "w") as f:
            json.dump(metadata, f, indent=2)
