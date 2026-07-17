import asyncio
import importlib
import os
import random
import shutil
import platform
import subprocess
from pathlib import Path
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
        self._current_model_path = None
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

        try:
            importlib.import_module("mlx_video")
        except ImportError:
            missing.append("mlx-video-with-audio")

        if missing:
            logger.warning(f"Missing optional dependencies for real generation: {', '.join(missing)}")
        else:
            logger.info("Real MLX/LTX/AV dependencies found.")

    def _ensure_dependency(self, name: str, action: str):
        try:
            importlib.import_module(name)
        except ImportError:
            raise DependencyError(name, action)

    def capabilities(self) -> List[str]:
        """Returns supported capabilities."""
        # In a real setup, we might check hardware here too.
        caps = ["text-to-video", "image-to-video", "audio-to-video"]
        # retake is planned but might not be in the first backend version
        return caps

    async def load_model(self, model_profile: Any) -> Any:
        model_id = getattr(model_profile, "id", str(model_profile))
        model_path = getattr(model_profile, "local_path", None)

        if not model_path:
            # Fallback to model_id if local_path is not provided
            from ai_video_worker.config import settings
            model_path = os.path.join(settings.models_dir, model_id)

        logger.info(f"MLXLTXAdapter: Loading model from {model_path} (ID: {model_id})")

        if not os.path.exists(model_path):
             logger.error(f"Model path {model_path} does not exist.")
             raise FileNotFoundError(f"Model path {model_path} does not exist.")

        is_av_model = getattr(model_profile, "model_type", None) == "AudioVideo"
        backend = getattr(model_profile, "backend", None)

        if not is_av_model and not backend:
            # Fallback for old/untyped profiles
            is_av_model = "av" in model_id.lower() or "av" in os.path.basename(model_path).lower()

        if backend == "mlx-video-with-audio" or is_av_model:
            try:
                importlib.import_module("mlx_video")
                self._current_model_id = model_id
                self._current_model_path = model_path
                self._pipeline = "AV_MODEL"
                logger.info(f"MLXLTXAdapter: {model_id} identified as AV model. Backend: {backend}")
                return {"status": "ready", "model_id": self._current_model_id, "backend": backend, "type": "AV"}
            except ImportError:
                logger.warning(f"AV model detected but mlx-video-with-audio not installed. Backend: {backend}")

        if backend == "ltx-diffusers":
            try:
                from ltx_video.pipelines.pipeline_ltx_video import LTXVideoPipeline
                logger.info("MLXLTXAdapter: Loading LTX Diffusers model (blocking call, offloading to thread)...")
                self._pipeline = await asyncio.to_thread(
                    LTXVideoPipeline.from_pretrained,
                    model_path,
                    ignore_mismatched_sizes=True
                )
                self._current_model_id = model_id
                self._current_model_path = model_path
                return {"status": "ready", "model_id": self._current_model_id, "backend": backend}
            except Exception as e:
                logger.error(f"Failed to load LTX Diffusers model: {e}")
                raise RuntimeError(f"Failed to load LTX model: {str(e)}")

        # Legacy/Fallback loading path
        try:
            from ltx_video.pipelines.pipeline_ltx_video import LTXVideoPipeline
        except ImportError:
            logger.error("ltx_video.pipelines.pipeline_ltx_video not found. Real generation requires ltx-video package.")
            raise DependencyError("ltx_video", "Please install ltx-video: pip install ltx-video")

        try:
            logger.info("MLXLTXAdapter: Calling from_pretrained (blocking call, offloading to thread)...")
            self._pipeline = await asyncio.to_thread(
                LTXVideoPipeline.from_pretrained,
                model_path,
                ignore_mismatched_sizes=True
            )
            self._current_model_id = model_id
            self._current_model_path = model_path
            return {"status": "loaded", "model_id": self._current_model_id}
        except Exception as e:
            logger.error(f"Failed to load LTX model: {e}")
            raise RuntimeError(f"Failed to load LTX model: {str(e)}")

    def _fix_flat_model_structure(self, model_path: str):
        """
        Organizes a flat model directory into the structure expected by Diffusers.
        Uses symlinks to avoid copying large files.
        """
        import json

        # Mapping of component name to expected filename and possible source files
        # For ltx-video 0.1.2+, transformer and vae expect a nested structure
        # (e.g. transformer/transformer/config.json) when loaded via Diffusers.
        components = {
            "transformer": {
                "weights": "diffusion_pytorch_model.safetensors",
                "sources": ["transformer.safetensors", "model.safetensors"],
                "config": "config.json",
                "nested": "transformer",
                "expected_config": {
                    "_class_name": "LTXVideoTransformer3DModel",
                    "_diffusers_version": "0.32.0.dev0",
                    "activation_fn": "gelu-approximate",
                    "attention_bias": True,
                    "attention_head_dim": 64,
                    "attention_out_bias": True,
                    "caption_channels": 4096,
                    "cross_attention_dim": 2048,
                    "in_channels": 128,
                    "norm_elementwise_affine": False,
                    "norm_eps": 1e-06,
                    "num_attention_heads": 32,
                    "num_layers": 28,
                    "out_channels": 128,
                    "patch_size": 1,
                    "patch_size_t": 1,
                    "qk_norm": "rms_norm_across_heads",
                },
            },
            "vae": {
                "weights": "diffusion_pytorch_model.safetensors",
                "sources": ["vae_decoder.safetensors", "vae.safetensors", "model.safetensors"],
                "config": "config.json",
                "nested": "vae",
                "expected_config": {
                    "_class_name": "AutoencoderKLLTXVideo",
                    "_diffusers_version": "0.32.0.dev0",
                    "block_out_channels": [128, 256, 512, 512],
                    "decoder_causal": False,
                    "encoder_causal": True,
                    "in_channels": 3,
                    "latent_channels": 128,
                    "layers_per_block": [4, 3, 3, 3, 4],
                    "out_channels": 3,
                    "patch_size": 4,
                    "patch_size_t": 1,
                    "resnet_norm_eps": 1e-06,
                    "scaling_factor": 1.0,
                    "spatio_temporal_scaling": [True, True, True, False],
                },
            },
            "text_encoder": {
                "weights": "model.safetensors",
                "sources": ["text_encoder.safetensors", "model.safetensors"],
                "config": "config.json",
                "fallback_dir": "t5-v1_1-xxl"
            },
            "tokenizer": {
                "weights": "spiece.model",
                "sources": ["tokenizer.model"],
                "config": "tokenizer_config.json",
                "fallback_dir": "t5-v1_1-xxl"
            },
            "scheduler": {
                "weights": None, # Schedulers usually only have config
                "sources": [],
                "config": "scheduler_config.json",
                "nested": "scheduler",
                "expected_config": {
                    "_class_name": "FlowMatchEulerDiscreteScheduler",
                    "_diffusers_version": "0.32.0.dev0",
                    "base_image_seq_len": 1024,
                    "base_shift": 0.95,
                    "invert_sigmas": False,
                    "max_image_seq_len": 4096,
                    "max_shift": 2.05,
                    "num_train_timesteps": 1000,
                    "shift": 1.0,
                    "shift_terminal": 0.1,
                    "use_beta_sigmas": False,
                    "use_dynamic_shifting": True,
                    "use_exponential_sigmas": False,
                    "use_karras_sigmas": False,
                },
            }
        }

        # Load embedded config if available to extract component configs
        embedded_config = {}
        embedded_path = os.path.join(model_path, "embedded_config.json")
        if os.path.exists(embedded_path):
            try:
                with open(embedded_path, "r") as f:
                    embedded_config = json.load(f)
            except Exception as e:
                logger.warning(f"Could not load embedded_config.json: {e}")

        for comp_name, info in components.items():
            comp_root = os.path.join(model_path, comp_name)
            # Ensure it's not a symlink to somewhere else that might cause recursion
            if os.path.islink(comp_root):
                 os.unlink(comp_root)
            os.makedirs(comp_root, exist_ok=True)

            # Support nested directory for ltx-video custom loading
            if "nested" in info:
                comp_dir = os.path.join(comp_root, info["nested"])
                os.makedirs(comp_dir, exist_ok=True)
            else:
                comp_dir = comp_root

            # 1. Handle Weights
            if info.get("weights"):
                dest_weights = os.path.join(comp_dir, info["weights"])
                if not os.path.exists(dest_weights):
                    for src_name in info["sources"]:
                        src_path = os.path.join(model_path, src_name)
                        if os.path.exists(src_path):
                            try:
                                # Use absolute path for symlink to be safe
                                os.symlink(os.path.abspath(src_path), dest_weights)
                                logger.info(f"Symlinked {src_name} to {comp_name}/{info['weights']}")
                                break
                            except Exception as e:
                                logger.warning(f"Failed to symlink {src_name}: {e}")

                    # If still no weights and we have a fallback_dir
                    if not os.path.exists(dest_weights) and "fallback_dir" in info:
                        fallback_path = os.path.join(os.path.dirname(model_path), info["fallback_dir"])
                        if os.path.exists(fallback_path):
                            logger.info(f"Using fallback directory {info['fallback_dir']} for {comp_name}")
                            # Symlink all files from fallback_dir to comp_dir
                            for f in os.listdir(fallback_path):
                                f_path = os.path.join(fallback_path, f)
                                if os.path.isfile(f_path):
                                    try:
                                        os.symlink(os.path.abspath(f_path), os.path.join(comp_dir, f))
                                    except FileExistsError:
                                        pass
                                    except Exception as e:
                                        logger.warning(f"Failed to symlink fallback file {f}: {e}")

            # 2. Handle Config
            dest_config = os.path.join(comp_dir, info["config"])
            if not os.path.exists(dest_config):
                # Try to extract from embedded_config
                if comp_name in embedded_config:
                    try:
                        config_data = embedded_config[comp_name]
                        # If we have an expected_config, we use it as a base/template
                        # but we might want to preserve some values if they are different?
                        # Actually, for LTX compatibility, it's safer to use the expected one
                        # if the current one doesn't match the library's hardcoded check.
                        if "expected_config" in info:
                            # Use the expected config to satisfy the library's from_pretrained check
                            config_data = info["expected_config"]

                        with open(dest_config, "w") as f:
                            json.dump(config_data, f, indent=2)
                        logger.info(f"Created config for {comp_name} (using compatibility template)")
                    except Exception as e:
                        logger.warning(f"Failed to write config for {comp_name}: {e}")
                # Fallback to root config.json or expected_config if available
                elif "expected_config" in info:
                    try:
                        with open(dest_config, "w") as f:
                            json.dump(info["expected_config"], f, indent=2)
                        logger.info(f"Created config for {comp_name} from compatibility template")
                    except Exception as e:
                        logger.warning(f"Failed to write template config for {comp_name}: {e}")
                elif os.path.exists(os.path.join(model_path, "config.json")):
                    try:
                        os.symlink(os.path.abspath(os.path.join(model_path, "config.json")), dest_config)
                        logger.info(f"Symlinked root config.json to {comp_name}/config.json")
                    except Exception as e:
                        logger.warning(f"Failed to symlink config.json for {comp_name}: {e}")

        # 3. Handle Legacy Scheduler code if it's still there (we now handle it in the loop above)
        # We can remove this block if we are sure the loop covers it correctly
        # But let's keep it for now but make it safe
        # (Actually, let's remove it to avoid confusion)
    async def unload_model(self, model_id: str) -> None:
        logger.info(f"MLXLTXAdapter: Unloading model {model_id}")
        self._current_model_id = None
        self._current_model_path = None
        self._pipeline = None

    async def generate_text_to_video(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        if not self._pipeline:
            raise RuntimeError("No model loaded. Call load_model first.")

        if self._pipeline == "AV_MODEL":
            return await self._generate_av(request, output_path, progress_callback, cancellation_token)

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
                    # Map 0-100% of steps to 15-90% of total job progress
                    progress = 0.15 + (step / total_steps) * 0.75
                    progress_callback("generating_video", progress, f"Step {step}/{total_steps}...")

            if progress_callback:
                progress_callback("preparing_inputs", 0.1, "Preparing generation inputs...")

            # Ensure we have a seed for reproducibility and to avoid MLX error
            if getattr(request, "seed", None) is None or getattr(request, "seed", -1) == -1:
                request.seed = random.randint(0, 2**32 - 1)
                logger.info(f"Generated random seed: {request.seed}")

            # Real call to the pipeline
            logger.info(f"MLXLTXAdapter: Starting LTX pipeline call (seed: {request.seed}). This may take a while...")

            if progress_callback:
                progress_callback("generating_video", 0.1, "Starting LTX generation (this can take several minutes)...")

            # Ensure output directory exists
            os.makedirs(os.path.dirname(output_path), exist_ok=True)

            # If a placeholder already exists (e.g. from a failed previous attempt or initial setup),
            # we will overwrite it with the real generation result.
            if os.path.exists(output_path):
                logger.info(f"MLXLTXAdapter: Overwriting existing placeholder/file at {output_path}")

            # Pipeline call is blocking. Run it in a thread.
            result = await asyncio.to_thread(
                self._pipeline,
                prompt=request.prompt,
                negative_prompt=getattr(request, "negative_prompt", ""),
                width=getattr(request, "width", 704),
                height=getattr(request, "height", 512),
                num_frames=getattr(request, "num_frames", 49),
                num_inference_steps=getattr(request, "steps", 20),
                guidance_scale=getattr(request, "guidance_scale", 3.0),
                seed=request.seed,
                callback=internal_callback if progress_callback else None,
            )

            if progress_callback:
                progress_callback("encoding_output", 0.95, "Encoding final MP4...")

            # Parse the real pipeline return type
            if hasattr(result, "frames"):
                result = result.frames

            if hasattr(result, "save"):
                result.save(output_path)
            elif isinstance(result, str) and os.path.exists(result):
                import shutil
                if result != output_path:
                    shutil.copy2(result, output_path)
            else:
                self._save_frames_as_video(result, output_path, fps=24)

            if not os.path.isfile(output_path) or os.path.getsize(output_path) == 0:
                raise RuntimeError("Generation completed without producing a valid video file")

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
        if not self._pipeline:
            raise RuntimeError("No model loaded. Call load_model first.")

        if self._pipeline == "AV_MODEL":
            return await self._generate_av(request, output_path, progress_callback, cancellation_token)

        logger.info(f"MLXLTXAdapter: Generating image-to-video for {request.prompt}")

        try:
            if progress_callback:
                progress_callback("processing_image", 0.2, "Processing input image...")

            from PIL import Image
            image = Image.open(request.image_path).convert("RGB")

            # Ensure we have a seed for reproducibility and to avoid MLX error
            if getattr(request, "seed", None) is None:
                request.seed = random.randint(0, 2**32 - 1)
                logger.info(f"Generated random seed: {request.seed}")

            def internal_callback(step: int, total_steps: int, **kwargs):
                if cancellation_token and cancellation_token.is_cancelled:
                    raise InterruptedError("Generation cancelled")
                if progress_callback:
                    # Map 0-100% of steps to 15-90% of total job progress
                    progress = 0.15 + (step / total_steps) * 0.75
                    progress_callback("generating_video", progress, f"Step {step}/{total_steps}...")

            # Pipeline call is blocking. Run it in a thread.
            result = await asyncio.to_thread(
                self._pipeline,
                prompt=request.prompt,
                image=image,
                negative_prompt=getattr(request, "negative_prompt", ""),
                width=getattr(request, "width", 704),
                height=getattr(request, "height", 512),
                num_frames=getattr(request, "num_frames", 49),
                num_inference_steps=getattr(request, "steps", 20),
                guidance_scale=getattr(request, "guidance_scale", 3.0),
                seed=request.seed,
                callback=internal_callback if progress_callback else None,
            )

            if progress_callback:
                progress_callback("encoding_output", 0.95, "Encoding final MP4...")

            # Parse the real pipeline return type
            if hasattr(result, "frames"):
                result = result.frames

            if hasattr(result, "save"):
                result.save(output_path)
            elif isinstance(result, str) and os.path.exists(result):
                import shutil
                if result != output_path:
                    shutil.copy2(result, output_path)
            else:
                self._save_frames_as_video(result, output_path, fps=24)

            if not os.path.isfile(output_path) or os.path.getsize(output_path) == 0:
                raise RuntimeError("Generation completed without producing a valid video file")

            return output_path

        except InterruptedError:
            logger.info("Generation cancelled in adapter")
            return ""
        except Exception as e:
            logger.error(f"LTX image-to-video failed: {e}")
            raise e

    async def _generate_av(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        """Generation implementation using mlx-video-with-audio."""
        logger.info(f"MLXLTXAdapter: AV Generation for {request.prompt}")

        try:
            from mlx_video.generate_av import generate_video_with_audio
        except ImportError:
            raise DependencyError("mlx-video-with-audio", "Please install: pip install mlx-video-with-audio")

        # Find text encoder path - default to common local path or let mlx-video handle repo ID
        from ai_video_worker.config import settings
        text_encoder_path = os.path.join(settings.models_dir, "gemma-3-12b-it-bf16")
        if not os.path.exists(text_encoder_path):
             text_encoder_path = "mlx-community/gemma-3-12b-it-bf16"

        try:
            def internal_callback(step: int, total_steps: int, **kwargs):
                if cancellation_token and cancellation_token.is_cancelled:
                    raise InterruptedError("Generation cancelled")
                if progress_callback:
                    # Map 0-100% of steps to 15-90% of total job progress
                    progress = 0.15 + (step / total_steps) * 0.75
                    progress_callback("generating_video", progress, f"Step {step}/{total_steps}...")

            if progress_callback:
                progress_callback("loading_model", 0.05, "Preparing unified AV model...")

            # Use local path if we have it
            model_repo = self._current_model_path if hasattr(self, "_current_model_path") else os.path.join(settings.models_dir, "ltx-video-av-q4")
            if not os.path.exists(model_repo):
                 model_repo = "notapalindrome/ltx23-mlx-av-q4"

            # Check if image is provided
            image_path = getattr(request, "image_path", None)

            # Ensure we have a seed for reproducibility and to avoid MLX error
            if getattr(request, "seed", None) is None or getattr(request, "seed", -1) == -1:
                request.seed = random.randint(0, 2**32 - 1)
                logger.info(f"Generated random seed: {request.seed}")

            # Note: mlx-video-with-audio might need specific arguments
            # We follow the pattern from av_generator.py in ltx-video-mac
            logger.info(f"MLXLTXAdapter: Starting unified AV generation (seed: {request.seed}). This may take a while...")

            if progress_callback:
                progress_callback("generating_video", 0.1, "Starting unified AV generation (this can take several minutes)...")

            # Ensure height/width are divisible by 64
            height = getattr(request, "height", 512)
            width = getattr(request, "width", 512)
            if height % 64 != 0:
                height = (height // 64) * 64
                logger.warning(f"MLXLTXAdapter: Adjusted height to {height} (must be divisible by 64)")
            if width % 64 != 0:
                width = (width // 64) * 64
                logger.warning(f"MLXLTXAdapter: Adjusted width to {width} (must be divisible by 64)")

            # Ensure output directory exists
            os.makedirs(os.path.dirname(output_path), exist_ok=True)

            # If a placeholder already exists, we will overwrite it with the real generation result.
            if os.path.exists(output_path):
                logger.info(f"MLXLTXAdapter: Overwriting existing placeholder/file at {output_path}")

            # Unified AV generation is blocking. Run it in a thread.
            # Note: generate_video_with_audio does not currently support progress callbacks.
            # We provide a simulated progress for UI purposes if it's supported by the worker infrastructure.
            logger.info(f"MLXLTXAdapter: Calling generate_video_with_audio for output: {output_path}")
            await asyncio.to_thread(
                generate_video_with_audio,
                model_repo=model_repo,
                text_encoder_repo=text_encoder_path,
                prompt=request.prompt,
                height=height,
                width=width,
                num_frames=getattr(request, "num_frames", 65),
                seed=request.seed,
                fps=getattr(request, "fps", 24),
                output_path=output_path,
                negative_prompt=getattr(request, "negative_prompt", None),
                cfg_scale=getattr(request, "guidance_scale", 3.0),
                image=image_path,
                num_inference_steps=getattr(request, "steps", 30),
                enhance_prompt=getattr(request, "enhance_prompt", False),
                use_uncensored_enhancer=getattr(request, "use_uncensored_enhancer", False),
                verbose=True,
                no_audio=False # We want audio in AV model
            )
            logger.info(f"MLXLTXAdapter: generate_video_with_audio completed for output: {output_path}")

            if progress_callback:
                progress_callback("completed", 1.0, "Generation finished")

            # Extract preview image for UI
            try:
                self._extract_preview(output_path)
            except Exception as e:
                logger.warning(f"Failed to extract preview: {e}")

            return output_path

        except InterruptedError:
            logger.info("AV Generation cancelled")
            return ""
        except Exception as e:
            logger.error(f"AV generation failed: {e}")
            raise e

    def _extract_preview(self, video_path: str):
        """Extracts the first frame of the video as a preview.jpg."""
        import cv2
        import os
        from pathlib import Path

        preview_path = str(Path(video_path).parent / "preview.jpg")

        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            logger.warning(f"Could not open video to extract preview: {video_path}")
            return

        ret, frame = cap.read()
        if ret:
            cv2.imwrite(preview_path, frame)
            logger.info(f"Extracted preview to {preview_path}")
        else:
            logger.warning(f"Could not read first frame from video: {video_path}")

        cap.release()

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
        if not self._pipeline:
            raise RuntimeError("No model loaded. Call load_model first.")

        if self._pipeline == "AV_MODEL":
            # AV model naturally generates audio, so we just use the AV generation path
            return await self._generate_av(request, output_path, progress_callback, cancellation_token)

        # For standard LTX, we don't have integrated AV generation in this adapter yet
        raise UnsupportedCapabilityError("audio-to-video", "Standard LTX model does not support integrated audio-video generation yet. Please use an AV model.")

    async def generate_retake(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        raise UnsupportedCapabilityError("retake")
