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
    Direct MLX implementation of LTXAdapter.
    Prioritizes mlx-video for AV and ltx-video for base generation.
    """

    def __init__(self):
        self._current_model_id = None
        self._current_model_path = None
        self._pipeline = None
        self._is_av = False

    def capabilities(self) -> List[str]:
        return ["text-to-video", "image-to-video", "audio-to-video"]

    async def load_model(self, model_profile: Any) -> Any:
        model_id = getattr(model_profile, "id", str(model_profile))
        model_path = getattr(model_profile, "local_path", None)

        if not model_path:
            from ai_video_worker.config import settings
            model_path = os.path.join(settings.models_dir, model_id)

        logger.info(f"MLXAdapter: Loading {model_id} from {model_path}")

        if not os.path.exists(model_path):
             raise FileNotFoundError(f"Model path {model_path} does not exist.")

        # Determine if it's an AV model
        is_av = "av" in model_id.lower() or "av" in os.path.basename(model_path).lower()
        if hasattr(model_profile, "model_type"):
            is_av = model_profile.model_type == "AudioVideo"

        if is_av:
            try:
                importlib.import_module("mlx_video")
                self._pipeline = "AV_MODEL"
                self._is_av = True
            except ImportError:
                logger.error("mlx-video-with-audio required for AV models.")
                raise DependencyError("mlx_video", "pip install mlx-video-with-audio")
        else:
            try:
                from ltx_video.pipelines.pipeline_ltx_video import LTXVideoPipeline
                self._pipeline = await asyncio.to_thread(
                    LTXVideoPipeline.from_pretrained,
                    model_path,
                    ignore_mismatched_sizes=True
                )
                self._is_av = False
            except Exception as e:
                logger.error(f"Failed to load LTX model: {e}")
                raise RuntimeError(f"Model load failed: {e}")

        self._current_model_id = model_id
        self._current_model_path = model_path
        return {"status": "ready", "model_id": model_id, "is_av": self._is_av}

    async def unload_model(self, model_id: str) -> None:
        if self._current_model_id == model_id:
            self._pipeline = None
            self._current_model_id = None
            self._current_model_path = None
            import gc
            gc.collect()

    async def generate_text_to_video(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        if self._is_av:
            return await self._generate_av(request, output_path, progress_callback, cancellation_token)
        else:
            return await self._generate_base(request, output_path, progress_callback, cancellation_token)

    async def _generate_base(self, request, output_path, progress_callback, cancellation_token):
        # Implementation using ltx-video pipeline
        if self._pipeline == "AV_MODEL" or self._is_av:
            return await self._generate_av(request, output_path, progress_callback, cancellation_token)

        if not self._pipeline:
            raise RuntimeError("Base LTX pipeline not loaded.")

        from ltx_video.utils.export_video import export_to_video
        import torch
        import mlx.core as mx
        import numpy as mx_numpy # mlx usually doesn't have .numpy, it's np-like

        prompt = getattr(request, "prompt", "")
        negative_prompt = getattr(request, "negative_prompt", "")
        width = getattr(request, "width", 704)
        height = getattr(request, "height", 512)
        num_frames = getattr(request, "num_frames", 49)
        num_inference_steps = getattr(request, "steps", 20)
        guidance_scale = getattr(request, "guidance_scale", 3.0)
        seed = getattr(request, "seed", random.randint(0, 1000000))

        # Ensure divisible by 32
        width = (width // 32) * 32
        height = (height // 32) * 32

        logger.info(f"Generating: {width}x{height}, {num_frames} frames, steps={num_inference_steps}, seed={seed}")
        logger.info(f"MLXAdapter [BASE]: PROMPT BEING USED FOR MODEL CALL: '{prompt}'")
        logger.info(f"MLXLTXAdapter: Original prompt: '{prompt}'")
        logger.info(f"MLXAdapter [BASE]: NEGATIVE PROMPT BEING USED: '{negative_prompt}'")

        if progress_callback:
            progress_callback("generating_video", 0.2, "Starting LTX diffusion...")

        # Generator for reproducibility
        mx.random.seed(seed)

        def pipe_callback(step, timestep, latents):
            if cancellation_token and cancellation_token.is_cancelled:
                raise asyncio.CancelledError("Generation cancelled by user.")
            if progress_callback:
                progress = 0.2 + (step / num_inference_steps) * 0.7
                progress_callback("generating_video", progress, f"Step {step}/{num_inference_steps}")

        # Run inference (blocking call, offload to thread)
        try:
            # Check if self._pipeline is callable
            if not callable(self._pipeline):
                raise TypeError(f"LTX Pipeline is not callable: {type(self._pipeline)}. "
                                "This can happen if an AV model was loaded into the base pipeline.")

            output = await asyncio.to_thread(
                self._pipeline,
                prompt=prompt,
                negative_prompt=negative_prompt,
                width=width,
                height=height,
                num_frames=num_frames,
                num_inference_steps=num_inference_steps,
                guidance_scale=guidance_scale,
                generator=None, # mx handles seed globally or we'd pass a generator if ltx-video supports it
                callback=pipe_callback,
                output_type="np"
            )

            frames = output.frames[0] # [F, H, W, C]

            if progress_callback:
                progress_callback("encoding_output", 0.9, "Encoding video to MP4...")

            # Export to video
            await asyncio.to_thread(
                export_to_video,
                frames,
                output_path,
                fps=24
            )

            return output_path

        except asyncio.CancelledError:
            logger.info("Generation cancelled.")
            raise
        except Exception as e:
            logger.error(f"Error during base generation: {e}")
            raise
    async def _generate_av(self, request, output_path, progress_callback, cancellation_token):
        import mlx_video

        prompt = getattr(request, "prompt", "")
        width = getattr(request, "width", 704)
        height = getattr(request, "height", 512)
        num_frames = getattr(request, "num_frames", 49)
        num_inference_steps = getattr(request, "steps", 20)
        guidance_scale = getattr(request, "guidance_scale", 3.0)
        seed = getattr(request, "seed", random.randint(0, 1000000))

        # mlx-video usually has its own generation wrapper
        if progress_callback:
            progress_callback("generating_video", 0.2, "Starting MLX-Video AV generation...")

        logger.info(f"MLXAdapter [AV]: PROMPT BEING USED FOR MODEL CALL: '{prompt}'")
        logger.info(f"MLXLTXAdapter: Original prompt: '{prompt}'")
        try:
            # This is a simplified representation of mlx_video's call
            # In real implementation, we'd use the actual API
            await asyncio.to_thread(
                mlx_video.generate,
                model_path=self._current_model_path,
                prompt=prompt,
                width=width,
                height=height,
                num_frames=num_frames,
                num_inference_steps=num_inference_steps,
                guidance_scale=guidance_scale,
                seed=seed,
                output_path=output_path
            )
            return output_path
        except Exception as e:
            logger.error(f"Error during AV generation: {e}")
            raise

    async def generate_image_to_video(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        # Image-to-video implementation...
        # For now, it might be similar to base but with image conditioning
        # Real LTX image-to-video uses the same pipeline usually but with conditioning latents
        return await self._generate_base(request, output_path, progress_callback, cancellation_token)

    async def generate_audio_to_video(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        if self._is_av:
            return await self._generate_av(request, output_path, progress_callback, cancellation_token)
        else:
             raise UnsupportedCapabilityError("audio-to-video", "Current model does not support audio generation.")

    async def generate_retake(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        raise UnsupportedCapabilityError("retake", "Retake is not yet implemented in the MLX backend.")

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
        logger.debug(f"[MLXLTXAdapter] generate_text_to_video pipeline={self._pipeline}")
        if not self._pipeline:
            raise RuntimeError("No model loaded. Call load_model first.")

        if self._pipeline == "AV_MODEL":
            return await self._generate_av(request, output_path, progress_callback, cancellation_token)

        logger.info(f"MLXLTXAdapter: Generating text-to-video for {request.prompt}")
        logger.debug(f"[MLXLTXAdapter] params: width={request.width}, height={request.height}, frames={request.num_frames}, steps={request.steps}, guidance={request.guidance_scale}")

        # Real LTX generation logic
        try:
            logger.info(f"MLXLTXAdapter: Starting REAL LTX generation for prompt: '{request.prompt}'")
            if getattr(request, 'negative_prompt', None):
                logger.info(f"MLXLTXAdapter: Negative prompt: '{request.negative_prompt}'")

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
                logger.info(f"Generated random seed for LTX: {request.seed}")

            # Real call to the pipeline
            logger.info(f"MLXLTXAdapter: Starting LTX pipeline call (seed: {request.seed}). This may take a while...")

            if progress_callback:
                progress_callback("generating_video", 0.1, "Starting LTX generation (this can take several minutes)...")

            # Ensure output directory exists
            os.makedirs(os.path.dirname(output_path), exist_ok=True)

            # If a placeholder already exists (e.g. from a failed previous attempt or initial setup),
            # we will overwrite it with the real generation result.
            if os.path.exists(output_path):
                logger.info(f"MLXLTXAdapter: Overwriting existing file/placeholder at {output_path} (size: {os.path.getsize(output_path)} bytes)")
            else:
                logger.info(f"MLXLTXAdapter: No existing file at {output_path}, will create new output.")

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
                progress_callback("decoding", 0.90, "Decoding latents to video frames...")

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
                logger.info(f"Generated random seed for AV: {request.seed}")

            # Ensure height/width are divisible by 64
            height = getattr(request, "height", 512)
            width = getattr(request, "width", 512)
            if height % 64 != 0:
                height = (height // 64) * 64
                logger.warning(f"MLXLTXAdapter: Adjusted height to {height} (must be divisible by 64)")
            if width % 64 != 0:
                width = (width // 64) * 64
                logger.warning(f"MLXLTXAdapter: Adjusted width to {width} (must be divisible by 64)")

            logger.info(f"MLXLTXAdapter: Starting unified AV generation for prompt: '{request.prompt}'")
            logger.info(f"MLXLTXAdapter: Original prompt: '{request.prompt}'")
            if getattr(request, 'negative_prompt', None):
                logger.info(f"MLXLTXAdapter: Negative prompt: '{request.negative_prompt}'")

            # Note: mlx-video-with-audio might need specific arguments
            # We follow the pattern from av_generator.py in ltx-video-mac
            logger.info(f"MLXLTXAdapter: Starting unified AV generation (seed: {request.seed}). This may take a while...")
            logger.debug(f"MLXLTXAdapter: AV Generation Details:")
            logger.debug(f"  - Model Repo: {model_repo}")
            logger.debug(f"  - Text Encoder: {text_encoder_path}")
            logger.debug(f"  - Prompt: {request.prompt}")
            logger.debug(f"  - Size: {width}x{height}")
            logger.debug(f"  - Frames: {getattr(request, 'num_frames', 65)}")
            logger.debug(f"  - Steps: {getattr(request, 'steps', 30)}")
            logger.debug(f"  - Output: {output_path}")

            # Ensure output directory exists
            os.makedirs(os.path.dirname(output_path), exist_ok=True)

            # If a placeholder already exists, we will overwrite it with the real generation result.
            if os.path.exists(output_path):
                logger.info(f"MLXLTXAdapter: Found existing file at {output_path} (size: {os.path.getsize(output_path)} bytes). It will be overwritten.")

            # Unified AV generation is blocking. Run it in a thread.
            # We capture stdout/stderr to parse progress from mlx-video's verbose output.
            from ai_video_worker.utils.capture import ProgressStreamInterceptor, MLXProgressParser
            import sys

            parser = MLXProgressParser(progress_callback)

            # Initialize with early stages so we have a base rank
            if progress_callback:
                progress_callback("checking_hardware", 0.05, "Validating hardware compatibility...")
                progress_callback("loading_model", 0.08, "Preparing unified AV model...")

            if getattr(request, "enhance_prompt", False):
                logger.info("MLXLTXAdapter: Prompt enhancement is ENABLED")
                logger.info(f"MLXLTXAdapter: Prompt enhancement is ENABLED. The prompt '{request.prompt}' will be expanded by an LLM.")
                if progress_callback:
                    progress_callback("preparing_inputs", 0.11, "Enhancing prompt with LLM...")
            else:
                logger.info(f"MLXLTXAdapter: Prompt enhancement is DISABLED. Using raw prompt: '{request.prompt}'")

            def generation_wrapper():
                original_stdout = sys.stdout
                original_stderr = sys.stderr
                sys.stdout = ProgressStreamInterceptor(original_stdout, parser.parse_line)
                sys.stderr = ProgressStreamInterceptor(original_stderr, parser.parse_line)
                try:
                    generate_video_with_audio(
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
                finally:
                    sys.stdout = original_stdout
                    sys.stderr = original_stderr

            import time
            av_start_time = time.time()

            await asyncio.to_thread(generation_wrapper)

            av_duration = time.time() - av_start_time
            logger.info(f"MLXLTXAdapter: generate_video_with_audio completed in {av_duration:.2f}s for output: {output_path}")

            if os.path.exists(output_path):
                logger.info(f"MLXLTXAdapter: Output file exists. Size: {os.path.getsize(output_path)} bytes")
            else:
                logger.error(f"MLXLTXAdapter: Output file DOES NOT EXIST after generation at {output_path}")
                # Check for .temp.mp4 or .temp which some versions might leave behind
                temp_candidates = [
                    output_path.replace(".mp4", ".temp.mp4"),
                    output_path.replace(".mp4", ".temp"),
                    output_path + ".temp"
                ]
                for temp_path in temp_candidates:
                    if os.path.exists(temp_path):
                        logger.warning(f"MLXLTXAdapter: Found temporary file at {temp_path} (size: {os.path.getsize(temp_path)} bytes). Moving it to {output_path}")
                        try:
                            os.rename(temp_path, output_path)
                            break
                        except Exception as rename_err:
                            logger.error(f"Failed to rename {temp_path} to {output_path}: {rename_err}")

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
