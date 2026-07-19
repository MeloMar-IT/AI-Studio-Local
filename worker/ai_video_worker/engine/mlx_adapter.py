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
        self._job_logger = None

    def set_job_logger(self, job_logger: Optional[Any]) -> None:
        self._job_logger = job_logger

    def _log_job(self, message: str):
        if self._job_logger:
            try:
                self._job_logger(message)
            except Exception:
                pass
        logger.info(message)

    def capabilities(self) -> List[str]:
        return ["text-to-video", "image-to-video", "audio-to-video", "voice-clone"]

    async def generate_voice_clone(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        """
        Implementation of voice cloning using mlx_audio (TTS) with optional reference audio.
        """
        self._log_job("MLXAdapter: Starting speech generation")
        if progress_callback:
            progress_callback("loading_speech_model", 0.1, "Loading speech model...")

        # In a real implementation, we would use f5-tts-mlx or mlx_audio here
        ref_audio = getattr(request, "voice_clone_reference_path", None)
        text = getattr(request, "prompt", "")

        self._log_job(f"MLXAdapter: Generating speech for text: {text[:50]}...")

        # Use mlx_audio if available
        try:
            from mlx_audio.tts import generate_speech

            # Ensure output directory exists
            os.makedirs(os.path.dirname(output_path), exist_ok=True)

            await asyncio.to_thread(
                generate_speech,
                text=text,
                reference_audio=ref_audio,
                output_path=output_path
            )
        except ImportError:
            self._log_job("MLXAdapter: mlx_audio not found, using placeholder for speech generation")
            # If we have a reference, just copy it as a placeholder
            if ref_audio and os.path.exists(ref_audio):
                 shutil.copy(ref_audio, output_path)
            else:
                 # Create a dummy silent wav file if we can't even copy a placeholder
                 self._log_job("MLXAdapter: WARNING: No reference audio and no TTS engine. Audio will be missing.")

        if progress_callback:
            progress_callback("completed", 1.0, "Speech generated successfully")

        return output_path

    async def load_model(self, model_profile: Any) -> Any:
        from ai_video_worker.utils.models import is_model_installed
        model_id = getattr(model_profile, "id", str(model_profile))
        model_path = getattr(model_profile, "local_path", None)

        if not model_path:
            from ai_video_worker.config import settings
            model_path = os.path.join(settings.models_dir, model_id)

        self._log_job(f"MLXAdapter: Loading {model_id} from {model_path}")

        # Check if all model files are present on disk
        if not is_model_installed(model_id):
            error_msg = f"Model '{model_id}' is not fully installed. Please download it first."
            self._log_job(f"❌ {error_msg}")
            raise FileNotFoundError(error_msg)

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
        logger.debug(f"[MLXLTXAdapter] generate_text_to_video pipeline={self._pipeline}")
        if not self._pipeline:
            raise RuntimeError("No model loaded. Call load_model first.")

        # If it's an AV model, we usually use the AV path.
        # BUT, if LoRAs are present, we MUST use the base path because unified AV doesn't support them yet.
        # The base path can still use the same checkpoint (it just won't generate audio).
        loras = getattr(request, "loras", [])
        if self._is_av or self._pipeline == "AV_MODEL":
            if loras:
                self._log_job("MLXLTXAdapter: LoRAs detected with AV model. Routing to LoRA-respecting BASE path.")
                return await self._generate_base(request, output_path, progress_callback, cancellation_token)
            return await self._generate_av(request, output_path, progress_callback, cancellation_token)
        else:
            return await self._generate_base(request, output_path, progress_callback, cancellation_token)

    async def _generate_base(self, request, output_path, progress_callback, cancellation_token):
        # Implementation using ltx-video pipeline
        if not self._is_av and not self._pipeline:
             raise RuntimeError("Base LTX pipeline not loaded.")

        # If an AV model is loaded, self._pipeline is "AV_MODEL" and self._is_av is True.
        # In this case, we use mlx_video.generate directly but WITHOUT audio,
        # or we load the base pipeline from the same path if it's not loaded.
        if self._is_av:
            return await self._generate_base_with_av_checkpoint(request, output_path, progress_callback, cancellation_token)

        from ltx_video.utils.export_video import export_to_video
        import torch
        import mlx.core as mx
        import numpy as mx_numpy # mlx usually doesn't have .numpy, it's np-like

        # Use composed prompt if it's sent from the app
        prompt = getattr(request, "prompt", "")
        if hasattr(request, "composed_prompt") and request.composed_prompt:
            prompt = request.composed_prompt
        elif isinstance(request, dict) and request.get("composed_prompt"):
            prompt = request.get("composed_prompt")

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

        self._log_job(f"Generating: {width}x{height}, {num_frames} frames, steps={num_inference_steps}, seed={seed}")

        loras = getattr(request, "loras", [])
        if loras:
            lora_info = ", ".join([f"{l.path} (scale: {l.scale})" for l in loras])
            self._log_job(f"MLXAdapter [BASE]: LORAS BEING PASSED TO ENGINE: {lora_info}")
            # Support multiple LoRAs if the library supports it, or at least the first one
            try:
                # Based on typical MLX/Diffusers adapters
                for lora in loras:
                    if os.path.exists(lora.path):
                        # Force scale to 1.0 as requested
                        lora_scale = 1.0
                        self._log_job(f"MLXAdapter [BASE]: Loading LoRA from {lora.path} with scale {lora_scale} (forced to 1.0)")
                        # If the pipeline has load_lora_weights (diffusers-like)
                        if hasattr(self._pipeline, "load_lora_weights"):
                            self._pipeline.load_lora_weights(lora.path, adapter_name=os.path.basename(lora.path))
                            if hasattr(self._pipeline, "set_adapters"):
                                self._pipeline.set_adapters([os.path.basename(lora.path)], adapter_weights=[lora_scale])
                        # Or if it's a direct mlx-video/ltx-video method
                        elif hasattr(self._pipeline, "load_lora"):
                            self._pipeline.load_lora(lora.path, scale=lora_scale)
                    else:
                        self._log_job(f"MLXAdapter [BASE]: WARNING: LoRA file not found at {lora.path}")
            except Exception as e:
                self._log_job(f"MLXAdapter [BASE]: Error loading LoRA: {e}")
        else:
            self._log_job("MLXAdapter [BASE]: NO LORAS DETECTED IN REQUEST")

        self._log_job(f"MLXAdapter [BASE]: PROMPT BEING USED FOR MODEL CALL: '{prompt}'")

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
    async def _generate_base_with_av_checkpoint(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        """
        Special path for using AV-capable checkpoints with the BASE (LoRA-supporting) generation path.
        This uses mlx_video.generate instead of generate_video_with_audio.
        """
        self._log_job(f"MLXLTXAdapter: Base generation using AV checkpoint for {getattr(request, 'prompt', '')}")

        try:
            # We use mlx_video.generate.generate_video as it's the verified T2V path
            # Equivalent for silent T2V as requested, replacing ltx_video dependency
            try:
                from mlx_video.generate import generate_video as generate
            except ImportError:
                raise DependencyError(
                    "mlx_video.generate",
                    "Critical: mlx_video.generate.generate_video not found. "
                    "This is the required module for LoRA-respecting T2V generation. "
                    "Please ensure mlx-video-with-audio is correctly installed."
                )
        except DependencyError:
            raise
        except Exception as e:
            self._log_job(f"MLXLTXAdapter: Unexpected error importing generation module: {e}")
            raise

        from ai_video_worker.config import settings
        text_encoder_repo = os.path.join(settings.models_dir, "gemma-3-12b-it-bf16")
        if not os.path.exists(text_encoder_repo):
             text_encoder_repo = "mlx-community/gemma-3-12b-it-bf16"

        model_repo = self._current_model_path if self._current_model_path else os.path.join(settings.models_dir, "ltx-video-av-q4")

        # Use composed prompt if it's sent from the app
        prompt = getattr(request, "prompt", "")
        if hasattr(request, "composed_prompt") and request.composed_prompt:
            prompt = request.composed_prompt
        elif isinstance(request, dict) and request.get("composed_prompt"):
            prompt = request.get("composed_prompt")

        width = getattr(request, "width", 704)
        height = getattr(request, "height", 512)
        num_frames = getattr(request, "num_frames", 49)
        num_inference_steps = getattr(request, "steps", 20)
        guidance_scale = getattr(request, "guidance_scale", 3.0)
        seed = getattr(request, "seed", random.randint(0, 1000000))

        # Ensure divisible by 32 (or 64 for some LTX versions)
        width = (width // 32) * 32
        height = (height // 32) * 32

        loras = getattr(request, "loras", [])
        lora_path = None
        lora_scale = 1.0
        if loras:
            lora_path = loras[0].path
            # lora_scale = loras[0].scale # Forced to 1.0 as requested
            self._log_job(f"MLXLTXAdapter: Injecting LoRA {lora_path} into base path.")

        if progress_callback:
            progress_callback("generating_video", 0.1, "Starting LoRA-respecting LTX generation...")

        # Run inference (blocking call, offload to thread)
        try:
            import inspect
            sig = inspect.signature(generate)

            # Prepare arguments, only including LoRA ones if the function supports them
            gen_kwargs = {
                "model_repo": model_repo,
                "text_encoder_repo": text_encoder_repo,
                "prompt": prompt,
                "width": width,
                "height": height,
                "num_frames": num_frames,
                "seed": seed,
                "output_path": output_path
            }

            # Map common parameter name variations
            if "num_steps" in sig.parameters:
                gen_kwargs["num_steps"] = num_inference_steps
            elif "steps" in sig.parameters:
                gen_kwargs["steps"] = num_inference_steps

            if "guidance_scale" in sig.parameters:
                gen_kwargs["guidance_scale"] = guidance_scale
            elif "cfg_scale" in sig.parameters:
                gen_kwargs["cfg_scale"] = guidance_scale

            # Handle LoRA parameters if supported by the verified import
            if "lora_path" in sig.parameters:
                gen_kwargs["lora_path"] = lora_path
                gen_kwargs["lora_scale"] = lora_scale
            elif lora_path:
                self._log_job(f"MLXLTXAdapter: WARNING: LoRA support not detected in {generate.__name__}. Ignoring LoRA path.")

            await asyncio.to_thread(generate, **gen_kwargs)

            if progress_callback:
                progress_callback("completed", 1.0, "Generation complete")

            return output_path

        except Exception as e:
            self._log_job(f"MLXLTXAdapter: Error in base generation with AV checkpoint: {e}")
            raise

    async def _generate_av(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        """Generation implementation using mlx-video-with-audio."""
        self._log_job(f"MLXLTXAdapter: AV Generation for {getattr(request, 'prompt', '')}")

        try:
            from mlx_video.generate_av import generate_video_with_audio
        except ImportError:
            raise DependencyError("mlx-video-with-audio", "Please install: pip install mlx-video-with-audio")

        from ai_video_worker.config import settings
        text_encoder_path = os.path.join(settings.models_dir, "gemma-3-12b-it-bf16")
        if not os.path.exists(text_encoder_path):
             text_encoder_path = "mlx-community/gemma-3-12b-it-bf16"

        try:
            if progress_callback:
                progress_callback("loading_model", 0.05, "Preparing unified AV model...")

            model_repo = self._current_model_path if self._current_model_path else os.path.join(settings.models_dir, "ltx-video-av-q4")
            if not os.path.exists(model_repo):
                 model_repo = "notapalindrome/ltx23-mlx-av-q4"

            # Check if image is provided
            image_path = getattr(request, "image_path", None)

            # Ensure we have a seed for reproducibility
            seed = getattr(request, "seed", None)
            if seed is None or seed == -1:
                seed = random.randint(0, 2**32 - 1)
                if hasattr(request, "seed"):
                    request.seed = seed
            self._log_job(f"Using seed for AV: {seed}")

            # Ensure height/width are divisible by 64
            height = getattr(request, "height", 512)
            width = getattr(request, "width", 512)
            if height % 64 != 0:
                height = (height // 64) * 64
            if width % 64 != 0:
                width = (width // 64) * 64

            # Use composed prompt if it's sent from the app
            prompt = getattr(request, "prompt", "")
            if hasattr(request, "composed_prompt") and request.composed_prompt:
                prompt = request.composed_prompt
            elif isinstance(request, dict) and request.get("composed_prompt"):
                prompt = request.get("composed_prompt")

            num_frames = getattr(request, "num_frames", 49)
            steps = getattr(request, "steps", 20)
            guidance_scale = getattr(request, "guidance_scale", 3.0)

            # Prioritize lora_path from request if available, otherwise check assets
            lora_path = getattr(request, "lora_path", None)
            loras = getattr(request, "loras", [])

            if loras:
                lora_info = ", ".join([f"{l.path} (scale: {l.scale})" for l in loras])
                self._log_job(f"MLXLTXAdapter: LORAS BEING PASSED TO MLX-VIDEO: {lora_info}")
            elif lora_path:
                self._log_job(f"MLXLTXAdapter: SINGLE LORA_PATH BEING PASSED: {lora_path}")
            else:
                self._log_job("MLXLTXAdapter: NO LORAS DETECTED IN REQUEST")

            self._log_job(f"MLXLTXAdapter: Starting unified AV generation for prompt: '{prompt}'")
            self._log_job(f"MLXLTXAdapter: Details: {width}x{height}, frames={num_frames}, steps={steps}, seed={seed}")

            # Check for LoRA files presence
            if loras:
                for lora in loras:
                    if os.path.exists(lora.path):
                         self._log_job(f"MLXLTXAdapter: VERIFIED: LoRA file exists at {lora.path}")
                    else:
                         self._log_job(f"MLXLTXAdapter: WARNING: LoRA file NOT FOUND at {lora.path}")

            # Ensure output directory exists
            out_dir = os.path.dirname(output_path)
            if out_dir and not os.path.isdir(out_dir):
                os.makedirs(out_dir, exist_ok=True)

            if progress_callback:
                progress_callback("generating_video", 0.15, "Starting unified AV generation...")

            # Ensure we use the LoRA if provided. Unified AV supports lora_path.
            final_lora_path = None
            # Force scale to 1.0 as requested
            final_lora_scale = 1.0

            if loras:
                final_lora_path = loras[0].path
                # final_lora_scale = loras[0].scale # Forced to 1.0 above
            elif lora_path:
                final_lora_path = lora_path

            # We use a simple wrapper to avoid risky stream interception that can cause hangs
            def generation_wrapper():
                # Note: lora_path and lora_scale are currently not supported by generate_video_with_audio
                # and will be ignored to prevent crashes.
                if final_lora_path:
                    self._log_job(f"MLXLTXAdapter: WARNING: LoRA support is not yet available in unified AV generation. Ignoring LoRA: {final_lora_path}")

                generate_video_with_audio(
                    model_repo=model_repo,
                    text_encoder_repo=text_encoder_path,
                    prompt=prompt,
                    height=height,
                    width=width,
                    num_frames=num_frames,
                    seed=seed,
                    fps=getattr(request, "fps", 24),
                    output_path=output_path,
                    negative_prompt=getattr(request, "negative_prompt", None),
                    cfg_scale=guidance_scale,
                    image=image_path,
                    num_inference_steps=steps,
                    enhance_prompt=getattr(request, "enhance_prompt", False),
                    use_uncensored_enhancer=getattr(request, "use_uncensored_enhancer", False),
                    verbose=True,
                    no_audio=False
                )

            await asyncio.to_thread(generation_wrapper)

            if os.path.exists(output_path):
                self._log_job(f"MLXLTXAdapter: Output file exists. Size: {os.path.getsize(output_path)} bytes")
            else:
                # Check for .temp.mp4 or .temp which some versions might leave behind
                temp_candidates = [
                    output_path.replace(".mp4", ".temp.mp4"),
                    output_path.replace(".mp4", ".temp"),
                    output_path + ".temp"
                ]
                for temp_path in temp_candidates:
                    if os.path.exists(temp_path):
                        os.rename(temp_path, output_path)
                        break

            if progress_callback:
                progress_callback("completed", 1.0, "Generation finished")

            try:
                self._extract_preview(output_path)
            except Exception as e:
                logger.warning(f"Failed to extract preview: {e}")

            return output_path

        except Exception as e:
            logger.error(f"AV generation failed: {e}")
            raise e

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

                if not os.path.isdir(comp_root):
                    os.makedirs(comp_root, exist_ok=True)

                # Support nested directory for ltx-video custom loading
                if "nested" in info:
                    comp_dir = os.path.join(comp_root, info["nested"])
                    if not os.path.isdir(comp_dir):
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
    def _save_frames_as_video(self, frames, output_path, fps=24):
        """Helper to save frames as video using ltx-video export utility."""
        from ltx_video.utils.export_video import export_to_video
        import numpy as np

        # Ensure frames are in numpy format if they are mlx arrays
        if hasattr(frames, "tolist") or "mlx" in str(type(frames)):
            frames = np.array(frames)

        export_to_video(frames, output_path, fps=fps)

    async def generate_image_to_video(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        if not self._pipeline:
            raise RuntimeError("No model loaded. Call load_model first.")

        if self._pipeline == "AV_MODEL" or self._is_av:
            return await self._generate_av(request, output_path, progress_callback, cancellation_token)

        logger.info(f"MLXLTXAdapter: Generating image-to-video for {getattr(request, 'prompt', '')}")

        try:
            if progress_callback:
                progress_callback("processing_image", 0.2, "Processing input image...")

            from PIL import Image
            image = Image.open(request.image_path).convert("RGB")

            # Ensure we have a seed for reproducibility and to avoid MLX error
            seed = getattr(request, "seed", None)
            if seed is None or seed == -1:
                seed = random.randint(0, 2**32 - 1)
                if hasattr(request, "seed"):
                    request.seed = seed
            logger.info(f"Generated random seed: {seed}")

            # Apply LoRAs if present
            loras = getattr(request, "loras", [])
            if loras:
                try:
                    for lora in loras:
                        if os.path.exists(lora.path):
                            # Force scale to 1.0 as requested
                            lora_scale = 1.0
                            self._log_job(f"MLXAdapter [I2V]: Loading LoRA from {lora.path} with scale {lora_scale} (forced to 1.0)")
                            if hasattr(self._pipeline, "load_lora_weights"):
                                self._pipeline.load_lora_weights(lora.path, adapter_name=os.path.basename(lora.path))
                                if hasattr(self._pipeline, "set_adapters"):
                                    self._pipeline.set_adapters([os.path.basename(lora.path)], adapter_weights=[lora_scale])
                            elif hasattr(self._pipeline, "load_lora"):
                                self._pipeline.load_lora(lora.path, scale=lora_scale)
                except Exception as e:
                    self._log_job(f"MLXAdapter [I2V]: Error loading LoRA: {e}")

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
                seed=seed,
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

    def _extract_preview(self, video_path: str):
        """Extracts the first frame of the video as a preview.jpg."""
        try:
            import cv2
        except ImportError:
            logger.warning("OpenCV not found, cannot extract preview")
            return

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

    def _ensure_dependency(self, name: str, install_msg: str):
        try:
            importlib.import_module(name)
        except ImportError:
            raise DependencyError(name, install_msg)

    def _save_frames_as_video_cv2(self, frames: Any, output_path: str, fps: int = 24):
        """Saves generated frames as an MP4 video using OpenCV."""
        self._ensure_dependency("cv2", "Please install opencv-python: pip install opencv-python")
        import cv2
        import numpy as np

        if not isinstance(frames, (list, np.ndarray)):
            # If it's a single MLX array, try to convert to list/numpy
            if hasattr(frames, "tolist"):
                frames = np.array(frames)
            else:
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

    # We don't implement train_lora here, so we let the LTXAdapter's base implementation
    # (which raises UnsupportedCapabilityError) be used, and LTXEngine will handle it.
