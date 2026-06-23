import asyncio
import importlib
import os
import platform
import subprocess
from typing import Any, List, Optional
from ai_video_worker.engine.adapter import LTXAdapter
from ai_video_worker.engine.base import (
    ProgressCallback,
    CancellationToken,
    UnsupportedCapabilityError,
    DependencyError
)
from ai_video_worker.logging_config import logger

class MLXLTXAdapter(LTXAdapter):
    """
    Real implementation of LTXAdapter using MLX.
    This class handles dependency checks and wraps the actual MLX/LTX library calls.
    """

    def __init__(self):
        self._current_model_id = None
        self._pipeline = None

    def _check_dependencies(self):
        """Checks if required MLX/LTX packages are installed."""
        missing = []
        try:
            importlib.import_module("mlx.core")
        except ImportError:
            missing.append("mlx")

        try:
            importlib.import_module("ltx_video")
        except ImportError:
            missing.append("ltx-video")

        if missing:
            logger.warning(f"Missing optional dependencies for real generation: {', '.join(missing)}")
        else:
            logger.info("Real MLX/LTX dependencies found.")

    def _ensure_dependency(self, name: str, action: str):
        try:
            importlib.import_module(name)
        except ImportError:
            raise DependencyError(name, action)

    def capabilities(self) -> List[str]:
        """Returns supported capabilities."""
        # In a real setup, we might check hardware here too.
        caps = ["text-to-video", "image-to-video"]
        # retake and audio-to-video are planned but might not be in the first backend version
        return caps

    async def load_model(self, model_profile: Any) -> Any:
        try:
            from ltx_video.pipeline import LTXVideoPipeline
        except ImportError:
            logger.error("ltx_video not found. Real generation requires ltx-video package.")
            raise DependencyError("ltx_video", "Please install ltx-video: pip install ltx-video")

        model_id = getattr(model_profile, "id", str(model_profile))
        model_path = getattr(model_profile, "local_path", None)

        if not model_path:
            # Fallback to model_id if local_path is not provided
            from ai_video_worker.config import settings
            model_path = os.path.join(settings.models_dir, model_id)

        logger.info(f"MLXLTXAdapter: Loading LTX model from {model_path}")

        try:
            # Real LTX loading logic
            if not os.path.exists(os.path.join(model_path, "config.json")) and not os.path.exists(os.path.join(model_path, "model_index.json")):
                 logger.error(f"Model path {model_path} does not look like a valid LTX model.")
                 raise FileNotFoundError(f"Model path {model_path} does not look like a valid LTX model.")

            self._pipeline = LTXVideoPipeline.from_pretrained(model_path)
            self._current_model_id = model_id
            return {"status": "loaded", "model_id": self._current_model_id}
        except Exception as e:
            logger.error(f"Failed to load LTX model: {e}")
            raise RuntimeError(f"Failed to load LTX model: {str(e)}")

    async def unload_model(self, model_id: str) -> None:
        logger.info(f"MLXLTXAdapter: Unloading model {model_id}")
        self._current_model_id = None
        self._pipeline = None

    async def generate_text_to_video(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        # self._ensure_dependency("mlx.core", "Please install mlx: pip install mlx")
        # self._ensure_dependency("ltx_video", "Please install ltx-video: pip install ltx-video")

        if not self._pipeline:
            raise RuntimeError("No model loaded. Call load_model first.")

        logger.info(f"MLXLTXAdapter: Generating text-to-video for {request.prompt}")

        # Real LTX generation logic
        try:
            # Wrapper for progress updates if the library supports it.
            # Assuming a standard callback pattern or we can wrap the generation loop.
            def internal_callback(step: int, total_steps: int, **kwargs):
                if cancellation_token and cancellation_token.is_cancelled:
                    # Some libraries support raising an exception to cancel
                    raise InterruptedError("Generation cancelled")
                if progress_callback:
                    progress = 0.3 + (step / total_steps) * 0.5
                    progress_callback("generating_video", progress, f"Step {step}/{total_steps}...")

            if progress_callback:
                progress_callback("preparing_inputs", 0.2, "Preparing generation inputs...")

            # Real call to the pipeline
            result = self._pipeline(
                prompt=request.prompt,
                negative_prompt=getattr(request, "negative_prompt", ""),
                width=getattr(request, "width", 704),
                height=getattr(request, "height", 480),
                num_frames=getattr(request, "num_frames", 161),
                num_inference_steps=getattr(request, "steps", 20),
                guidance_scale=getattr(request, "guidance_scale", 3.0),
                seed=getattr(request, "seed", None),
                callback=internal_callback if progress_callback else None,
            )

            if progress_callback:
                progress_callback("encoding_output", 0.95, "Encoding final MP4...")

                # The result is expected to be a path or we save it to output_path
                # If result is frames, we'd use an encoder. Assuming pipeline handles export for now
                # or returns frames that we need to save.
                # Based on standard MLX pipelines, it might return a Video object or frames.
                if hasattr(result, "save"):
                    result.save(output_path)
                elif isinstance(result, str) and os.path.exists(result):
                    import shutil
                    shutil.copy(result, output_path)
                else:
                    # If it returned frames/numpy array
                    self._save_frames_as_video(result, output_path, fps=24)

            return output_path

        except InterruptedError:
            logger.info("Generation cancelled in adapter")
            return ""
        except Exception as e:
            logger.error(f"LTX generation failed: {e}")
            raise e

    async def generate_image_to_video(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        # self._ensure_dependency("mlx.core", "Please install mlx: pip install mlx")
        # self._ensure_dependency("ltx_video", "Please install ltx-video: pip install ltx-video")

        if not self._pipeline:
            raise RuntimeError("No model loaded. Call load_model first.")

        logger.info(f"MLXLTXAdapter: Generating image-to-video for {request.prompt}")

        try:
            if progress_callback:
                progress_callback("processing_image", 0.2, "Processing input image...")

            from PIL import Image
            image = Image.open(request.image_path).convert("RGB")

            def internal_callback(step: int, total_steps: int, **kwargs):
                if cancellation_token and cancellation_token.is_cancelled:
                    raise InterruptedError("Generation cancelled")
                if progress_callback:
                    progress = 0.35 + (step / total_steps) * 0.5
                    progress_callback("generating_video", progress, f"Step {step}/{total_steps}...")

            # Real call to the pipeline with image
            if self._pipeline == "mock_pipeline":
                logger.info("Using mock pipeline for image-to-video generation")
                await asyncio.sleep(2)
                self._generate_placeholder_video(
                    output_path,
                    getattr(request, "width", 704),
                    getattr(request, "height", 480),
                    getattr(request, "num_frames", 161)
                )
            else:
                result = self._pipeline(
                    prompt=request.prompt,
                    image=image,
                    negative_prompt=getattr(request, "negative_prompt", ""),
                    width=getattr(request, "width", 704),
                    height=getattr(request, "height", 480),
                    num_frames=getattr(request, "num_frames", 161),
                    num_inference_steps=getattr(request, "steps", 20),
                    guidance_scale=getattr(request, "guidance_scale", 3.0),
                    seed=getattr(request, "seed", None),
                    callback=internal_callback if progress_callback else None,
                )

                if progress_callback:
                    progress_callback("encoding_output", 0.95, "Encoding final MP4...")

                if hasattr(result, "save"):
                    result.save(output_path)
                elif isinstance(result, str) and os.path.exists(result):
                    import shutil
                    shutil.copy(result, output_path)
                else:
                    self._save_frames_as_video(result, output_path, fps=24)

            return output_path

        except InterruptedError:
            logger.info("Generation cancelled in adapter")
            return ""
        except Exception as e:
            logger.error(f"LTX image-to-video failed: {e}")
            raise e

    def _save_frames_as_video(self, frames: Any, output_path: str, fps: int = 24):
        """Saves generated frames as an MP4 video using OpenCV."""
        self._ensure_dependency("cv2", "Please install opencv-python: pip install opencv-python")
        import cv2
        import numpy as np

        if not isinstance(frames, (list, np.ndarray)):
            raise ValueError(f"Expected list or numpy array of frames, got {type(frames)}")

        if len(frames) == 0:
            raise ValueError("No frames to save")

        first_frame = frames[0]
        if hasattr(first_frame, "convert"):  # PIL Image
            first_frame = np.array(first_frame.convert("RGB"))

        height, width, _ = first_frame.shape

        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        out = cv2.VideoWriter(output_path, fourcc, fps, (width, height))

        for frame in frames:
            if hasattr(frame, "convert"):  # PIL Image
                frame = np.array(frame.convert("RGB"))
            # Convert RGB to BGR for OpenCV
            bgr_frame = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
            out.write(bgr_frame)
        out.release()
        logger.info(f"Saved {len(frames)} frames to {output_path}")

    async def generate_audio_to_video(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        raise UnsupportedCapabilityError("audio-to-video")

    async def generate_retake(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        raise UnsupportedCapabilityError("retake")
