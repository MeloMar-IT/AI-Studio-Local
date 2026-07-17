import asyncio
import json
import os
import platform
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

import psutil
from ai_video_worker.config import settings
from ai_video_worker.engine.base import (
    CancellationToken,
    GenerationEngine,
    ProgressCallback,
    UnsupportedCapabilityError,
    DependencyError,
)
from ai_video_worker.engine.adapter import LTXAdapter
from ai_video_worker.logging_config import logger


class LTXGenerationEngine(GenerationEngine):
    """
    Real LTX generation engine that delegates to an adapter.
    This class handles high-level workflow, validation, and metadata.
    """

    def __init__(self, adapter: Optional[LTXAdapter] = None):
        if adapter is None:
            from ai_video_worker.engine.mlx_adapter import MLXLTXAdapter
            self.adapter = MLXLTXAdapter()
        else:
            self.adapter = adapter

    def capabilities(self) -> List[str]:
        return self.adapter.capabilities()

    async def load_model(self, model_profile: Any) -> Any:
        logger.info(f"Loading model: {getattr(model_profile, 'id', str(model_profile))}")
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
        # Automatically load model if not already loaded or different model requested
        model_id = getattr(request, "model_id", None)
        if model_id and self.adapter._current_model_id != model_id:
            if progress_callback:
                progress_callback("loading_model", 0.1, f"Loading model {model_id}...")

            # Find the model profile
            from ai_video_worker.utils.models import scan_models
            models = scan_models(settings.models_dir)
            profile = next((m for m in models if m.id == model_id), None)

            # Use profile if found, otherwise use model_id as string
            # If profile is None, load_model will handle model_id string
            await self.load_model(profile if profile is not None else model_id)

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
        # Automatically load model if not already loaded or different model requested
        model_id = getattr(request, "model_id", None)
        if model_id and self.adapter._current_model_id != model_id:
            if progress_callback:
                progress_callback("loading_model", 0.1, f"Loading model {model_id}...")

            # Find the model profile
            from ai_video_worker.utils.models import scan_models
            models = scan_models(settings.models_dir)
            profile = next((m for m in models if m.id == model_id), None)

            # Use profile if found, otherwise use model_id as string
            # If profile is None, load_model will handle model_id string
            await self.load_model(profile if profile is not None else model_id)

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
        logger.debug(f"[_run_generation] job_id={job_id} method={method.__name__} output_path={output_path}")

        try:
            # 1. Hardware Validation
            if progress_callback:
                progress_callback("checking_hardware", 0.05, "Validating hardware compatibility...")
            self._validate_hardware()

            # 2. Generation execution via adapter
            logger.info(f"Starting generation for job {job_id} using {method.__name__}")
            result_path = await method(
                request,
                output_path,
                progress_callback=progress_callback,
                cancellation_token=cancellation_token
            )

            if cancellation_token and cancellation_token.is_cancelled:
                logger.info(f"Generation for job {job_id} was cancelled.")
                return ""

            # 3. Preview Generation
            logger.debug(f"Generation finished in {time.time() - start_time:.2f}s, starting post-processing for job {job_id}")
            if progress_callback:
                progress_callback("saving_metadata", 0.92, "Generating preview image...")
            preview_path = Path(output_path).parent / "preview.jpg"
            try:
                self._extract_preview(result_path, str(preview_path))
            except Exception as e:
                logger.warning(f"Failed to extract preview: {e}")
                # Do not write dummy content. UI should handle missing preview.

            # 4. Save Composed Prompt
            if progress_callback:
                progress_callback("saving_metadata", 0.95, "Saving composed prompt...")
            prompt_path = Path(output_path).parent / "composed-prompt.md"
            with open(prompt_path, "w") as f:
                f.write(f"# Composed Prompt\n\n{getattr(request, 'prompt', 'No prompt')}\n")

            # 5. Metadata Preservation
            if progress_callback:
                progress_callback("saving_metadata", 0.98, "Saving detailed metadata...")
            generation_time = time.time() - start_time
            self._save_detailed_metadata(job_id, request, result_path, generation_time)

            if progress_callback:
                progress_callback("completed", 1.0, "Generation finished")

            return result_path

        except (UnsupportedCapabilityError, DependencyError) as e:
            # Re-raise clean errors
            logger.error(f"Generation engine error: {e}")
            if progress_callback:
                progress_callback("failed", 1.0, f"Error: {str(e)}")
            raise e
        except Exception as e:
            logger.error(f"Generation failed: {e}")
            if progress_callback:
                progress_callback("failed", 1.0, f"Unexpected error: {str(e)}")
            raise e

    def _validate_hardware(self):
        """Validates that the current Mac appears compatible."""
        logger.debug(f"[_validate_hardware] Checking hardware compatibility. min_memory_gb={settings.min_memory_gb}")
        # Check for Apple Silicon
        if platform.machine() != "arm64":
            logger.warning("Not running on Apple Silicon. MLX might be slow or unsupported.")

        # Try to check for LTX dependencies in a way that doesn't block the whole engine
        try:
            import importlib
            importlib.import_module("ltx_video")
        except ImportError:
            # We don't raise DependencyError here anymore, let the adapter handle it
            # so it can fall back to mock if needed.
            logger.warning("ltx_video not found during hardware validation. Adapter will handle fallback.")

        # Check memory
        mem = psutil.virtual_memory()
        total_gb = mem.total / (1024**3)
        available_gb = mem.available / (1024**3)
        logger.debug(f"[_validate_hardware] Total RAM: {total_gb:.2f}GB, Available RAM: {available_gb:.2f}GB")
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

        # Calculate image hash if image_path exists
        image_path = req_data.get("image_path")
        image_hash = None
        if image_path and os.path.exists(image_path):
            try:
                import hashlib
                with open(image_path, "rb") as f:
                    image_hash = hashlib.sha256(f.read()).hexdigest()
            except Exception as e:
                logger.warning(f"Failed to calculate image hash: {e}")

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
            "image_path": image_path,
            "image_hash": image_hash,
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
        logger.debug(f"[_save_detailed_metadata] Writing metadata to {metadata_path}")
        with open(metadata_path, "w") as f:
            json.dump(metadata, f, indent=2, default=str)

    def _extract_preview(self, video_path: str, preview_path: str):
        """Extracts the first frame of the video as a preview image."""
        try:
            import cv2
            cap = cv2.VideoCapture(video_path)
            success, frame = cap.read()
            if success:
                cv2.imwrite(preview_path, frame)
                logger.info(f"Extracted preview to {preview_path}")
            else:
                logger.warning(f"Could not read first frame from {video_path}")
            cap.release()
        except ImportError:
            # Fallback to ffmpeg if cv2 is not available
            logger.info("OpenCV not available for preview extraction, trying ffmpeg")
            import subprocess
            try:
                subprocess.run([
                    "ffmpeg", "-i", video_path,
                    "-ss", "00:00:00",
                    "-vframes", "1",
                    "-q:v", "2",
                    preview_path,
                    "-y"
                ], check=True, capture_output=True)
                logger.info(f"Extracted preview via ffmpeg to {preview_path}")
            except Exception as e:
                logger.error(f"ffmpeg preview extraction failed: {e}")
                raise e
        except Exception as e:
            logger.error(f"Preview extraction failed: {e}")
            raise e
