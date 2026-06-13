import asyncio
import json
import os
import platform
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

import psutil
from ltx_worker.config import settings
from ltx_worker.engine.base import (
    CancellationToken,
    GenerationEngine,
    ProgressCallback,
    UnsupportedCapabilityError,
    DependencyError,
)
from ltx_worker.engine.adapter import LTXAdapter
from ltx_worker.logging_config import logger


class LTXGenerationEngine(GenerationEngine):
    """
    Real LTX generation engine that delegates to an adapter.
    This class handles high-level workflow, validation, and metadata.
    """

    def __init__(self, adapter: Optional[LTXAdapter] = None):
        if adapter is None:
            from ltx_worker.engine.mlx_adapter import MLXLTXAdapter
            self.adapter = MLXLTXAdapter()
        else:
            self.adapter = adapter

    def capabilities(self) -> List[str]:
        return self.adapter.capabilities()

    async def load_model(self, model_profile: Any) -> Any:
        return await self.adapter.load_model(model_profile)

    async def unload_model(self, model_id: str) -> None:
        await self.adapter.unload_model(model_id)

    async def generate_text_to_video(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        return await self._run_generation(
            self.adapter.generate_text_to_video,
            request,
            output_path,
            progress_callback,
            cancellation_token
        )

    async def generate_image_to_video(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        return await self._run_generation(
            self.adapter.generate_image_to_video,
            request,
            output_path,
            progress_callback,
            cancellation_token
        )

    async def generate_audio_to_video(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        return await self._run_generation(
            self.adapter.generate_audio_to_video,
            request,
            output_path,
            progress_callback,
            cancellation_token
        )

    async def generate_retake(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        return await self._run_generation(
            self.adapter.generate_retake,
            request,
            output_path,
            progress_callback,
            cancellation_token
        )

    async def generate(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        # Backward compatibility / Generic entry point
        if hasattr(request, "image_path") and request.image_path:
             return await self.generate_image_to_video(request, output_path, progress_callback, cancellation_token)
        return await self.generate_text_to_video(request, output_path, progress_callback, cancellation_token)

    async def _run_generation(
        self,
        method: Any,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        start_time = time.time()
        job_id = Path(output_path).parent.name

        try:
            # 1. Hardware Validation
            if progress_callback:
                progress_callback("checking_hardware", 0.05, "Validating hardware compatibility...")
            self._validate_hardware()

            # 2. Generation execution via adapter
            result_path = await method(
                request,
                output_path,
                progress_callback=progress_callback,
                cancellation_token=cancellation_token
            )

            if cancellation_token and cancellation_token.is_cancelled:
                return ""

            # 3. Preview Generation
            if progress_callback:
                progress_callback("saving_metadata", 0.96, "Generating preview image...")
            preview_path = Path(output_path).parent / "preview.jpg"
            # In a real implementation, we would extract a frame from result_path
            with open(preview_path, "wb") as f:
                f.write(b"dummy jpg content")

            # 4. Save Composed Prompt
            if progress_callback:
                progress_callback("saving_metadata", 0.98, "Saving composed prompt...")
            prompt_path = Path(output_path).parent / "composed-prompt.md"
            with open(prompt_path, "w") as f:
                f.write(f"# Composed Prompt\n\n{getattr(request, 'prompt', 'No prompt')}\n")

            # 5. Metadata Preservation
            generation_time = time.time() - start_time
            self._save_detailed_metadata(job_id, request, result_path, generation_time)

            return result_path

        except (UnsupportedCapabilityError, DependencyError) as e:
            # Re-raise clean errors
            logger.error(f"Generation engine error: {e}")
            raise e
        except Exception as e:
            logger.error(f"Generation failed: {e}")
            raise e

    def _validate_hardware(self):
        """Validates that the current Mac appears compatible."""
        # Check for Apple Silicon
        if platform.machine() != "arm64":
            logger.warning("Not running on Apple Silicon. MLX might be slow or unsupported.")

        # Check memory
        mem = psutil.virtual_memory()
        total_gb = mem.total / (1024**3)
        if total_gb < settings.min_memory_gb:
            raise RuntimeError(
                f"Insufficient memory: {total_gb:.1f}GB. "
                f"LTX requires at least {settings.min_memory_gb}GB."
            )

    def _save_detailed_metadata(
        self,
        job_id: str,
        request: Any,
        output_path: str,
        generation_time: float
    ):
        """Saves detailed metadata.json as required."""
        # Ensure we can handle both dict and Pydantic models
        if hasattr(request, "model_dump"):
            req_data = request.model_dump()
        elif hasattr(request, "dict"):
            req_data = request.dict()
        elif isinstance(request, dict):
            req_data = request
        else:
            req_data = {}

        metadata = {
            "generation_id": job_id,
            "project_id": req_data.get("project_id"),
            "scene_id": req_data.get("scene_id"),
            "timestamp": datetime.now().isoformat(),
            "app_version": settings.version,
            "worker_version": settings.version,
            "model_id": req_data.get("model_id"),
            "prompt": req_data.get("prompt"),
            "composed_prompt": req_data.get("prompt"), # For now they are the same
            "negative_prompt": req_data.get("negative_prompt"),
            "seed": req_data.get("seed"),
            "resolution": f"{req_data.get('width', 0)}x{req_data.get('height', 0)}",
            "aspect_ratio": f"{req_data.get('width', 0)}:{req_data.get('height', 0)}",
            "fps": 24, # Default or from request if added later
            "duration_frames": req_data.get("num_frames"),
            "steps": req_data.get("steps"),
            "guidance_scale": req_data.get("guidance_scale"),
            "generation_time_seconds": round(generation_time, 2),
            "output_path": str(output_path),
            "preview_path": str(Path(output_path).parent / "preview.jpg"),
            "device_info": {
                "machine": platform.machine(),
                "processor": platform.processor(),
                "system": platform.system(),
                "memory_gb": round(psutil.virtual_memory().total / (1024**3), 2)
            }
        }

        metadata_path = Path(output_path).parent / "metadata.json"
        with open(metadata_path, "w") as f:
            json.dump(metadata, f, indent=2, default=str)
