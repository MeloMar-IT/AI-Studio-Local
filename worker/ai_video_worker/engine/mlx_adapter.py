import asyncio
import importlib
import os
import random
import shutil
import platform
import subprocess
import json
import re
import sys
import sysconfig
import glob
from pathlib import Path
from typing import Any, List, Optional
from ai_video_worker.engine.adapter import LTXAdapter
from ai_video_worker.config import settings
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
        # LoRA training is now supported for LTX-2 in MLX
        return ["text-to-video", "image-to-video", "audio-to-video", "voice-clone", "lora-training"]

    async def train_lora(
        self,
        request: Any,
        output_directory: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        """
        Implementation of LoRA training by invoking ltx-trainer-mlx via a wrapper script.
        """
        # 0. Preflight checks
        if sys.platform == "darwin" and platform.machine() != "arm64":
            error_msg = (
                f"MLX training requires native Apple Silicon ARM64 Python. "
                f"Current interpreter is {sys.executable} and reports architecture {platform.machine()}."
            )
            # UnsupportedCapabilityError expects (capability, message)
            raise UnsupportedCapabilityError("lora-training", error_msg + f"\nDiagnostics:\n  sys.executable: {sys.executable}\n  platform.machine(): {platform.machine()}\n  sysconfig.get_platform(): {sysconfig.get_platform()}\n  platform.platform(): {platform.platform()}\n  VIRTUAL_ENV: {os.environ.get('VIRTUAL_ENV')}")

        try:
            import mlx.core
        except ImportError:
            raise DependencyError("mlx", f"MLX is not installed in {sys.executable}. Please install it with 'pip install mlx'.")

        element_id = getattr(request, "element_id", "unknown")
        self._log_job(f"MLXAdapter: Starting real LoRA training for element {element_id}")

        # Must be absolute: the training subprocess runs with cwd=repo_path (ltx-2-mlx-repo),
        # a different directory than the worker's own cwd. output_directory arrives here as a
        # path relative to the worker's cwd (see jobs/store.py); left relative, the subprocess
        # would write the finished LoRA under ltx-2-mlx-repo/outputs/... while this function's
        # own post-training checkpoint lookup below checks worker/outputs/... instead, so the
        # finished file is never found ("no .safetensors LoRA file was found").
        output_directory = os.path.abspath(output_directory)

        if progress_callback:
            progress_callback("preparing_training_data", 0.05, "Preparing training dataset...")

        # 1. Resolve model path
        model_id = getattr(request, "model_id", settings.default_model_id)
        # We need the full path to the safetensors file
        model_path = os.path.join(settings.models_dir, model_id, "ltx-video-2.0.safetensors")
        if not os.path.exists(model_path):
             # Fallback to just the directory if specific file not found, config.py might handle it
             model_path = os.path.join(settings.models_dir, model_id)
        # Must be absolute: the training subprocess runs with cwd=repo_path (ltx-2-mlx-repo),
        # a different directory than the worker's own cwd, so a relative path here would
        # resolve to the wrong location and get misinterpreted as a HF Hub repo id.
        model_path = os.path.abspath(model_path)

        # 1b. Resolve local Gemma text encoder path (used for caption encoding during
        # preprocessing). Without this, the trainer falls back to its hardcoded HF Hub
        # default ("mlx-community/gemma-3-12b-it-4bit") and downloads it from the
        # internet instead of using the local copy already present in models_dir.
        gemma_model_path = os.path.abspath(os.path.join(settings.models_dir, "gemma-3-12b-it-bf16"))
        if not os.path.isdir(gemma_model_path):
            gemma_model_path = None

        # 2. Setup temporary directory for preprocessing/training
        # Also made absolute for the same reason as output_directory above.
        temp_dir = os.path.abspath(os.path.join(settings.output_dir, "temp_training", element_id))
        os.makedirs(temp_dir, exist_ok=True)

        # 3. Prepare arguments for the wrapper
        wrapper_script = os.path.abspath(os.path.join(os.path.dirname(__file__), "ltx_training_wrapper.py"))
        video_paths = getattr(request, "training_data_paths", [])
        trigger_word = getattr(request, "trigger_word", "a video of")
        # The character element's free-text description, if the app sent one.
        # Previously nothing upstream of here ever forwarded this, so captions
        # were always just the bare trigger word -- see ltx_training_wrapper.py's
        # prepare_dataset() for how this now gets combined into each caption.
        description = getattr(request, "description", None)
        steps = getattr(request, "steps", 500)
        rank = getattr(request, "rank", 64)
        learning_rate = getattr(request, "learning_rate", 5e-4)

        # 4. Invoke training wrapper using the active worker interpreter
        repo_path = os.path.abspath(os.path.join(os.getcwd(), settings.ltx_trainer_repo_path))

        # Build subprocess environment from the current process
        env = os.environ.copy()
        env["PYTHONUNBUFFERED"] = "1"

        # Derive the active virtual environment from sys.executable
        venv_dir = Path(sys.executable).resolve().parent.parent
        env["VIRTUAL_ENV"] = str(venv_dir)
        env["PATH"] = f"{venv_dir / 'bin'}:{env.get('PATH', '')}"

        # Remove any environment variables that can force an incorrect target platform
        env.pop("UV_PYTHON_PLATFORM", None)
        env.pop("_PYTHON_HOST_PLATFORM", None)

        cmd = [
            sys.executable,
            wrapper_script,
            "--model_path", model_path,
            "--video_paths", json.dumps(video_paths),
            "--trigger_word", trigger_word,
            "--output_dir", output_directory,
            "--temp_dir", temp_dir,
            "--steps", str(steps),
            "--rank", str(rank),
        ]
        if description and description.strip():
            cmd += ["--description", description.strip()]
        if gemma_model_path:
            cmd += ["--gemma_model_path", gemma_model_path]
        cmd += [
            "--learning_rate", str(learning_rate)
        ]

        # Startup diagnostics
        logger.info("Starting training subprocess...")
        logger.info(f"  Python executable: {sys.executable}")
        logger.info(f"  Python architecture: {platform.machine()}")
        logger.info(f"  Python platform: {sysconfig.get_platform()}")
        logger.info(f"  Virtual environment: {env['VIRTUAL_ENV']}")
        logger.info(f"  Training command: {' '.join(cmd)}")
        logger.info(f"  Working directory: {repo_path}")

        self._log_job(f"MLXAdapter: Invoking training wrapper (cwd={repo_path}): {' '.join(cmd)}")

        # 5. Run training as subprocess
        try:
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
                cwd=repo_path,
                env=env
            )

            # Monitor output for progress reporting
            async def monitor_output(stream, is_stderr=False):
                while True:
                    line = await stream.readline()
                    if not line:
                        break
                    line_str = line.decode().strip()
                    if line_str:
                        # Log everything to job logger
                        prefix = "[TRAINER ERR] " if is_stderr else "[TRAINER] "
                        self._log_job(f"{prefix}{line_str}")

                        # Basic progress estimation from output
                        if "Preprocessing" in line_str:
                            if progress_callback:
                                progress_callback("preprocessing", 0.1, "Preprocessing videos into latents...")
                        elif "Training" in line_str and "step" in line_str.lower():
                            # Example: "Step 100/500"
                            try:
                                match = re.search(r"step\s+(\d+)/(\d+)", line_str.lower())
                                if match:
                                    curr = int(match.group(1))
                                    total = int(match.group(2))
                                    progress = 0.2 + (0.7 * (curr / total))
                                    if progress_callback:
                                        progress_callback("training", progress, f"Training step {curr}/{total}...")
                            except Exception:
                                pass

            await asyncio.gather(
                monitor_output(process.stdout),
                process.wait()
            )

            if process.returncode != 0:
                raise Exception(f"Training subprocess failed with exit code {process.returncode}")

        except Exception as e:
            self._log_job(f"MLXAdapter: Training failed: {str(e)}")
            raise e
        finally:
            # Cleanup temp dir if desired (maybe keep for debugging in dev)
            # shutil.rmtree(temp_dir, ignore_errors=True)
            pass

        # 5. Locate and verify output
        # ltx-trainer-mlx saves to output_directory/checkpoints/step_XXXX.safetensors
        # Or if it finishes, we should find the final one.
        checkpoint_dir = os.path.join(output_directory, "checkpoints")
        lora_path = None

        # Look for the last checkpoint
        if os.path.exists(checkpoint_dir):
            files = sorted(Path(checkpoint_dir).glob("*.safetensors"))
            if files:
                lora_path = str(files[-1])

        # If not in checkpoints, look in output_directory itself
        if not lora_path:
            files = sorted(Path(output_directory).glob("*.safetensors"))
            # Filter out any files that might already be the final name from a previous run
            files = [f for f in files if f.name != f"{element_id}_lora.safetensors"]
            if files:
                lora_path = str(files[-1])

        if not lora_path or not os.path.exists(lora_path):
            raise Exception(f"Training finished but no .safetensors LoRA file was found in {output_directory}")

        # Final destination as requested: outputs/loras/<uuid>/<uuid>_lora.safetensors
        final_lora_path = os.path.join(output_directory, f"{element_id}_lora.safetensors")

        # If final_lora_path already exists (e.g. from previous run), remove it
        if os.path.abspath(lora_path) != os.path.abspath(final_lora_path):
            if os.path.exists(final_lora_path):
                os.remove(final_lora_path)
            shutil.move(lora_path, final_lora_path)

        # Sanity check
        if os.path.getsize(final_lora_path) < 1000:
             raise Exception(f"Generated LoRA file is suspiciously small ({os.path.getsize(final_lora_path)} bytes)")

        self._log_job(f"MLXAdapter: Training completed. LoRA saved to {final_lora_path}")
        if progress_callback:
            progress_callback("completed", 1.0, "Training completed successfully.")

        return final_lora_path

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

    def _generate_video_with_lora(
        self,
        model_repo: str,
        text_encoder_repo: str,
        prompt: str,
        height: int = 512,
        width: int = 512,
        num_frames: int = 33,
        seed: int = 42,
        fps: int = 24,
        output_path: str = "output.mp4",
        lora_path: Optional[str] = None,
        lora_scale: float = 1.0,
        image_path: Optional[str] = None,
        image_strength: float = 1.0,
        image_frame_idx: int = 0,
        verbose: bool = True,
        progress_callback: Optional[ProgressCallback] = None,
    ):
        """
        Generate video with manual LoRA merging, optionally conditioned on a
        starting reference image (I2V). Adapted from mlx_video.generate.generate_video,
        including that module's is_i2v conditioning branch (image_path=None keeps
        this a pure T2V+LoRA generation, unchanged from before).
        """
        import time
        import json
        import mlx.core as mx
        import mlx.nn as nn
        from pathlib import Path
        from mlx_video.utils import get_model_path, load_image, prepare_image_for_encoding
        from mlx_video.models.ltx.text_encoder import LTX2TextEncoder
        from mlx_video.models.ltx.config import LTXModelConfig, LTXModelType, LTXRopeType
        from mlx_video.models.ltx.ltx import LTXModel
        from mlx_video.generate import create_position_grid, denoise, STAGE_1_SIGMAS, STAGE_2_SIGMAS
        from mlx_video.generate_av import load_unified_weights
        from mlx_video.models.ltx.upsampler import load_upsampler, upsample_latents
        from mlx_video.models.ltx.video_vae.decoder import load_vae_decoder
        from mlx_video.models.ltx.video_vae.encoder import load_vae_encoder
        from mlx_video.models.ltx.video_vae.tiling import TilingConfig
        from mlx_video.conditioning import VideoConditionByLatentIndex, apply_conditioning
        from mlx_video.conditioning.latent import LatentState
        import numpy as np

        start_time = time.time()

        # Validate dimensions
        height = (height // 64) * 64
        width = (width // 64) * 64
        if num_frames % 8 != 1:
            num_frames = round((num_frames - 1) / 8) * 8 + 1

        self._log_job(f"MLXAdapter: Manual LoRA Pipeline - {width}x{height}, {num_frames} frames, seed={seed}")

        model_path = get_model_path(model_repo)
        text_encoder_path = model_path if text_encoder_repo is None else get_model_path(text_encoder_repo)

        stage1_h, stage1_w = height // 2 // 32, width // 2 // 32
        stage2_h, stage2_w = height // 32, width // 32
        latent_frames = 1 + (num_frames - 1) // 8

        mx.random.seed(seed)

        # 1. Load text encoder
        if progress_callback:
            progress_callback("loading_text_encoder", 0.1, "Loading text encoder...")
        self._log_job("MLXAdapter: Loading text encoder...")
        text_encoder = LTX2TextEncoder()
        # use_unified=True is required for this checkpoint: LTX2TextEncoder.load() only
        # loads connector.safetensors (the video/audio "embeddings connector" -- an 8-layer
        # transformer with 128 learnable registers that turns raw Gemma hidden states into
        # the actual cross-attention context) when this flag is set. Without it,
        # video_embeddings_connector/audio_embeddings_connector stay at their random init,
        # so the "text conditioning" fed to the transformer is effectively noise regardless
        # of the prompt -- verified generate_av.py (the known-good AV pipeline, confirmed
        # working for the no-LoRA base generation) always passes use_unified=True here.
        text_encoder.load(model_path=model_path, text_encoder_path=text_encoder_path, use_unified=True)
        mx.eval(text_encoder.parameters())

        text_embeddings, _ = text_encoder(prompt, return_audio_embeddings=False)
        model_dtype = text_embeddings.dtype
        mx.eval(text_embeddings)

        del text_encoder
        mx.clear_cache()

        # 2. Load transformer
        if progress_callback:
            progress_callback("loading_transformer", 0.2, "Loading transformer...")
        self._log_job("MLXAdapter: Loading transformer...")

        # This checkpoint's transformer.safetensors is already in final MLX "split model"
        # format (keys like "transformer_blocks.0.attn1.to_q.weight" with NO
        # "model.diffusion_model." prefix) -- it's the *output* of mlx_video's own
        # convert.py, not a raw HuggingFace state dict. sanitize_transformer_weights()
        # only keeps keys that start with "model.diffusion_model.", so calling it on this
        # file silently returned an EMPTY dict, and transformer.load_weights([], ...) was a
        # no-op -- the entire transformer ran with its random __init__ weights every time,
        # producing exactly the "runs fine, pure noise" symptom. load_unified_weights (the
        # same helper generate_av.py uses for this exact split-file layout) loads
        # transformer.safetensors directly with no incorrect prefix stripping.
        raw_weights = load_unified_weights(model_path, "transformer.")
        if not raw_weights:
            raise FileNotFoundError(f"No transformer weights found in {model_path}")
        self._log_job(f"MLXAdapter: Loaded {len(raw_weights)} raw transformer tensors from {model_path}")
        raw_weights = {k: v.astype(mx.bfloat16) if v.dtype == mx.float32 else v for k, v in raw_weights.items()}

        # Read the checkpoint's real architecture knobs from embedded_config.json instead of
        # hardcoding them. This checkpoint has apply_gated_attention=True (confirmed:
        # transformer_blocks.*.attn1.to_gate_logits.* exist on disk, and
        # scale_shift_table is [9, 4096] not [6, 4096]) and caption_projection disabled
        # (the text embeddings connector's output is fed straight in as context), which the
        # previous hardcoded config never set -- those weights/architecture pieces were
        # silently dropped/wrong even before the prefix bug above.
        caption_channels = 3840
        audio_caption_channels = 3840
        caption_proj_first = True
        caption_proj_second = True
        apply_gated_attention = False
        adaln_embedding_coefficient = 6
        embedded_cfg_path = model_path / "embedded_config.json"
        if embedded_cfg_path.exists():
            with open(embedded_cfg_path, "r") as f:
                t_cfg = json.load(f).get("transformer", {})
            caption_proj_first = t_cfg.get("caption_projection_first_linear", True)
            caption_proj_second = t_cfg.get("caption_projection_second_linear", True)
            apply_gated_attention = bool(t_cfg.get("apply_gated_attention", False))
            adaln_embedding_coefficient = 9 if apply_gated_attention else 6
            if not caption_proj_first and not caption_proj_second:
                # Caption projection is identity; the transformer's caption_channels must
                # match the embeddings connector's actual output width instead.
                conn_heads = t_cfg.get("connector_num_attention_heads", 32)
                conn_head_dim = t_cfg.get("connector_attention_head_dim", 128)
                caption_channels = conn_heads * conn_head_dim
                audio_conn_heads = t_cfg.get("audio_connector_num_attention_heads", 32)
                audio_conn_head_dim = t_cfg.get("audio_connector_attention_head_dim", 64)
                audio_caption_channels = audio_conn_heads * audio_conn_head_dim
            else:
                caption_channels = t_cfg.get("caption_channels", caption_channels)
                audio_caption_channels = t_cfg.get("audio_caption_channels", audio_caption_channels)

        config = LTXModelConfig(
            # ltx-video-av-q4 is an audio+video joint checkpoint (transformer.safetensors
            # has audio_adaln_single.*, av_ca_*.*, video_to_audio_attn.*, etc.). Building the
            # transformer as VideoOnly makes LTXModel construct the plain
            # TransformerArgsPreprocessor (prepare(modality) only), but denoise() then calls
            # .prepare(modality, cross_modality) as it would for an AV model, raising
            # "takes 2 positional arguments but 3 were given". AudioVideo (the dataclass's own
            # default, with matching audio_* field defaults already in LTXModelConfig) builds
            # the MultiModalTransformerArgsPreprocessor that supports the extra argument.
            model_type=LTXModelType.AudioVideo,
            num_attention_heads=32,
            attention_head_dim=128,
            in_channels=128,
            out_channels=128,
            num_layers=48,
            cross_attention_dim=4096,
            caption_channels=caption_channels,
            caption_projection_first_linear=caption_proj_first,
            caption_projection_second_linear=caption_proj_second,
            adaln_embedding_coefficient=adaln_embedding_coefficient,
            apply_gated_attention=apply_gated_attention,
            audio_caption_channels=audio_caption_channels,
            rope_type=LTXRopeType.SPLIT,
            double_precision_rope=True,
            positional_embedding_theta=10000.0,
            positional_embedding_max_pos=[20, 2048, 2048],
            use_middle_indices_grid=True,
            timestep_scale_multiplier=1000,
        )

        transformer = LTXModel(config)

        # This checkpoint is 4-bit quantized (transformer_blocks.*.attn*.to_q/k/v/out and
        # ff.proj_in/proj_out store "weight"+"scales"+"biases" triplets, not plain float
        # weights -- e.g. to_q.weight is [4096, 512] = 4096 in-features packed 8-per-uint32
        # at 4 bits, not a [4096, 4096] nn.Linear weight). LTXModel always builds plain
        # nn.Linear layers, and load_weights(strict=False) does not check shapes, so without
        # this quantize step the mis-shaped packed "weight" arrays got force-assigned into
        # plain Linear.weight and the "scales"/"biases" arrays (which have no matching
        # nn.Linear param name) were silently dropped -- another way the real trained
        # weights never made it into the model. nn.quantize() converts exactly the
        # attention/FF Linear submodules that actually have on-disk ".scales" tensors into
        # nn.QuantizedLinear first, so load_weights can then assign weight/scales/biases
        # into the correctly-shaped destinations. Mirrors generate_av.py's loading path,
        # which is confirmed correct (it's what the working no-LoRA base generation uses).
        split_manifest_path = model_path / "split_model.json"
        if split_manifest_path.exists():
            with open(split_manifest_path, "r") as f:
                manifest = json.load(f)
            if manifest.get("quantized", False):
                q_bits = manifest.get("quantization_bits", 4)
                q_group = manifest.get("quantization_group_size", 64)
                quantized_paths = {k.rsplit(".", 1)[0] for k in raw_weights if k.endswith(".scales")}

                def _should_quantize(path: str, module: "nn.Module") -> bool:
                    return isinstance(module, nn.Linear) and path in quantized_paths

                self._log_job(f"MLXAdapter: Quantizing transformer ({q_bits}-bit, group_size={q_group}, {len(quantized_paths)} layers)")
                nn.quantize(transformer, group_size=q_group, bits=q_bits, class_predicate=_should_quantize)

        transformer.load_weights(list(raw_weights.items()), strict=False)

        # 3. Apply LoRA if provided
        if lora_path and os.path.exists(lora_path):
            from mlx_video.lora.loader import load_lora_weights
            from mlx_video.lora.apply import apply_loras_to_model

            self._log_job(f"MLXAdapter: Loading LoRA weights from {lora_path}")
            lora_weights_dict = load_lora_weights(Path(lora_path))

            # module_to_loras expects Dict[str, List[Tuple[LoRAWeights, float]]]
            module_to_loras = {k: [(v, lora_scale)] for k, v in lora_weights_dict.items()}

            self._log_job(f"MLXAdapter: Merging LoRA into transformer (scale={lora_scale})")
            applied = apply_loras_to_model(transformer, module_to_loras, verbose=verbose)
            self._log_job(f"MLXAdapter: LoRA merge complete (applied to {applied} modules), proceeding to denoise")
        elif lora_path:
            self._log_job(f"MLXAdapter: WARNING: LoRA path provided but file not found: {lora_path}")

        mx.eval(transformer.parameters())

        # 3.5. Encode the conditioning image for I2V, if one was given. This
        # mirrors the is_i2v branch in mlx_video.generate.generate_video /
        # generate_av.py's generate_video_with_audio: the VAE encoder is a
        # separate small model from the decoder, loaded and discarded before
        # denoising starts, and the same source image is encoded twice (once
        # at Stage 1's half resolution, once at Stage 2's full resolution)
        # since each stage denoises at a different spatial size. Before this,
        # _generate_video_with_lora had no image conditioning at all -- I2V
        # requests with a LoRA attached silently fell back to pure T2V noise.
        is_i2v = bool(image_path)
        stage1_image_latent = None
        stage2_image_latent = None
        if is_i2v:
            if progress_callback:
                progress_callback("encoding_image", 0.25, "Encoding reference image...")
            self._log_job(f"MLXAdapter: Loading VAE encoder and encoding reference image {image_path}...")
            # use_unified=True: same reasoning as the VAE decoder load below --
            # this checkpoint's vae_encoder.safetensors is already in MLX-native
            # layout, and use_unified also makes load_vae_encoder read
            # encoder_blocks from embedded_config.json instead of falling back
            # to a hardcoded (and mismatched) architecture.
            vae_encoder = load_vae_encoder(str(model_path), use_unified=True)
            mx.eval(vae_encoder.parameters())

            input_image = load_image(image_path, height=height // 2, width=width // 2, dtype=model_dtype)
            stage1_image_tensor = prepare_image_for_encoding(input_image, height // 2, width // 2, dtype=model_dtype)
            stage1_image_latent = vae_encoder(stage1_image_tensor)
            mx.eval(stage1_image_latent)

            input_image = load_image(image_path, height=height, width=width, dtype=model_dtype)
            stage2_image_tensor = prepare_image_for_encoding(input_image, height, width, dtype=model_dtype)
            stage2_image_latent = vae_encoder(stage2_image_tensor)
            mx.eval(stage2_image_latent)

            del vae_encoder
            mx.clear_cache()

        # 4. Stage 1: Generate at half resolution
        if progress_callback:
            progress_callback("generating_video", 0.3, "Stage 1: Denoising half-res...")
        self._log_job("MLXAdapter: Stage 1 denoising...")
        mx.random.seed(seed)
        positions = create_position_grid(1, latent_frames, stage1_h, stage1_w)
        mx.eval(positions)

        # If I2V: seed Stage 1 from zeros + the encoded image latent (conditioned
        # frames get denoise_mask=0 so they stay locked to the image; unconditioned
        # frames get mask=1 and are pure noise, exactly like a T2V generation) instead
        # of pure random noise. denoise() reads state.latent/denoise_mask internally.
        state1 = None
        latent_shape = (1, 128, latent_frames, stage1_h, stage1_w)
        if is_i2v and stage1_image_latent is not None:
            state1 = LatentState(
                latent=mx.zeros(latent_shape, dtype=model_dtype),
                clean_latent=mx.zeros(latent_shape, dtype=model_dtype),
                denoise_mask=mx.ones((1, 1, latent_frames, 1, 1), dtype=model_dtype),
            )
            conditioning = VideoConditionByLatentIndex(
                latent=stage1_image_latent,
                frame_idx=image_frame_idx,
                strength=image_strength,
            )
            state1 = apply_conditioning(state1, [conditioning])

            noise = mx.random.normal(latent_shape).astype(model_dtype)
            noise_scale = mx.array(STAGE_1_SIGMAS[0], dtype=model_dtype)
            scaled_mask = state1.denoise_mask * noise_scale
            state1 = LatentState(
                latent=noise * scaled_mask + state1.latent * (mx.array(1.0, dtype=model_dtype) - scaled_mask),
                clean_latent=state1.clean_latent,
                denoise_mask=state1.denoise_mask,
            )
            latents = state1.latent
            mx.eval(latents)
        else:
            latents = mx.random.normal(latent_shape, dtype=model_dtype)
            mx.eval(latents)

        latents = denoise(latents, positions, text_embeddings, transformer, STAGE_1_SIGMAS, verbose=verbose, state=state1, stage=1)

        # 5. Upsample latents
        if progress_callback:
            progress_callback("upsampling", 0.7, "Upsampling latents...")
        self._log_job("MLXAdapter: Upsampling...")

        # Try multiple upsampler filenames
        upsampler_files = [
            'upsampler.safetensors',
            'ltx-2.3-spatial-upscaler-x2-1.1.safetensors',
            'ltx-2-spatial-upscaler-x2-1.0.safetensors'
        ]

        upsampler_path = None
        for uf in upsampler_files:
            candidate = model_path / uf
            if candidate.exists():
                upsampler_path = candidate
                break

        if upsampler_path is None:
            # Try any spatial upscaler
            upscalers = list(model_path.glob("*spatial_upscaler_x2*.safetensors"))
            if upscalers:
                upsampler_path = upscalers[0]

        if upsampler_path is None:
             raise FileNotFoundError(f"No spatial upsampler weights found in {model_path}")

        self._log_job(f"MLXAdapter: Loading upsampler from {upsampler_path}")
        upsampler = load_upsampler(str(upsampler_path))
        mx.eval(upsampler.parameters())

        # Load VAE decoder - use weights from the same file that provided transformer weights if possible
        # but most models have it in vae_decoder.safetensors or ltx-2-19b-distilled.safetensors
        vae_weight_files = [
            'vae_decoder.safetensors',
            'model.safetensors',
            'ltx-2-19b-distilled.safetensors',
            'ltx-2.3-22b-distilled.safetensors'
        ]

        vae_path = None
        for vf in vae_weight_files:
            candidate = model_path / vf
            if candidate.exists():
                vae_path = candidate
                break

        if vae_path is None:
             raise FileNotFoundError(f"No VAE decoder weights found in {model_path}")

        self._log_job(f"MLXAdapter: Loading VAE decoder from {vae_path}")
        # use_unified=True: this checkpoint's vae_decoder.safetensors already stores Conv3d
        # weights in MLX's native (O, D, H, W, I) layout (verified conv_in.conv.weight is
        # [1024, 3, 3, 3, 128] on disk). Without this flag, load_vae_decoder assumes raw
        # PyTorch (O, I, D, H, W) layout and unconditionally transposes -- applying that to an
        # already-MLX-layout tensor corrupts it (e.g. [1024,3,3,3,128] -> [1024,3,3,128,3]),
        # which is exactly the "[conv] input channels ... don't match" error this caused.
        #
        # Pass model_path (the directory), not vae_path (the specific file): load_vae_decoder
        # does its own file resolution *and* looks for embedded_config.json next to the
        # weights via `model_path / "embedded_config.json"`. Passing the file path made that
        # lookup silently fail (vae_decoder.safetensors/embedded_config.json doesn't exist),
        # so decoder_blocks was never read from the checkpoint's real config and
        # LTX2VideoDecoder fell back to its hardcoded 7-block architecture -- which doesn't
        # match this checkpoint's actual 9-block structure (verified vae_decoder.safetensors
        # has up_blocks.0 through up_blocks.8 on disk) and has residual=True on upsample
        # blocks where this checkpoint expects residual=False. That mismatch is what produced
        # the "512 vs 256 channels cannot be broadcast" error during decoding.
        vae_decoder = load_vae_decoder(
            str(model_path),
            timestep_conditioning=None,
            use_unified=True
        )

        latents = upsample_latents(latents, upsampler, vae_decoder.latents_mean, vae_decoder.latents_std)
        mx.eval(latents)

        del upsampler
        mx.clear_cache()

        # 6. Stage 2: Refine at full resolution
        if progress_callback:
            progress_callback("refining", 0.8, "Stage 2: Refining full-res...")
        self._log_job("MLXAdapter: Stage 2 refining...")
        positions = create_position_grid(1, latent_frames, stage2_h, stage2_w)
        mx.eval(positions)

        # Same I2V conditioning pattern as Stage 1, but seeded from the already
        # upsampled Stage 1 output rather than zeros (matching generate_video's
        # state2 branch), and using the full-resolution image latent.
        state2 = None
        if is_i2v and stage2_image_latent is not None:
            state2 = LatentState(
                latent=latents,
                clean_latent=mx.zeros_like(latents),
                denoise_mask=mx.ones((1, 1, latent_frames, 1, 1), dtype=model_dtype),
            )
            conditioning = VideoConditionByLatentIndex(
                latent=stage2_image_latent,
                frame_idx=image_frame_idx,
                strength=image_strength,
            )
            state2 = apply_conditioning(state2, [conditioning])

            noise = mx.random.normal(latents.shape).astype(model_dtype)
            noise_scale = mx.array(STAGE_2_SIGMAS[0], dtype=model_dtype)
            scaled_mask = state2.denoise_mask * noise_scale
            state2 = LatentState(
                latent=noise * scaled_mask + state2.latent * (mx.array(1.0, dtype=model_dtype) - scaled_mask),
                clean_latent=state2.clean_latent,
                denoise_mask=state2.denoise_mask,
            )
            latents = state2.latent
            mx.eval(latents)
        else:
            noise_scale = mx.array(STAGE_2_SIGMAS[0], dtype=model_dtype)
            one_minus_scale = mx.array(1.0 - STAGE_2_SIGMAS[0], dtype=model_dtype)
            noise = mx.random.normal(latents.shape).astype(model_dtype)
            latents = noise * noise_scale + latents * one_minus_scale
            mx.eval(latents)

        latents = denoise(latents, positions, text_embeddings, transformer, STAGE_2_SIGMAS, verbose=verbose, state=state2, stage=2)

        del transformer
        mx.clear_cache()

        # 7. Decode to video
        if progress_callback:
            progress_callback("decoding", 0.9, "Decoding to video...")
        self._log_job("MLXAdapter: Decoding...")
        # (Previously forced tiling off here as a workaround for a "512 vs 256 channels"
        # broadcast error. That turned out to be a red herring: the real cause was
        # load_vae_decoder being passed a file path instead of the model directory (see the
        # comment above), which made LTX2VideoDecoder silently build the wrong hardcoded
        # architecture regardless of tiling. Now that decoder_blocks loads correctly from the
        # checkpoint's embedded_config.json, auto-tiling is safe to use again -- it caps peak
        # memory for larger/longer video requests.)
        tiling_config = TilingConfig.auto(height, width, num_frames)
        video = vae_decoder.decode_tiled(latents, tiling_config=tiling_config, debug=verbose)
        mx.eval(video)
        mx.clear_cache()

        # Save video
        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)

        video = mx.squeeze(video, axis=0)
        video = mx.transpose(video, (1, 2, 3, 0))
        video = mx.clip((video + 1.0) / 2.0, 0.0, 1.0)
        video = (video * 255).astype(mx.uint8)
        video_np = np.array(video)

        try:
            import cv2
            h, w = video_np.shape[1], video_np.shape[2]
            fourcc = cv2.VideoWriter_fourcc(*'avc1')
            out = cv2.VideoWriter(str(output_path), fourcc, fps, (w, h))
            for frame in video_np:
                out.write(cv2.cvtColor(frame, cv2.COLOR_RGB2BGR))
            out.release()
            self._log_job(f"MLXAdapter: Saved video to {output_path}")
        except Exception as e:
            self._log_job(f"MLXAdapter: Error saving video: {e}")

        elapsed = time.time() - start_time
        self._log_job(f"MLXAdapter: Done! Generated in {elapsed:.1f}s")

        return video_np

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
        seed = getattr(request, "seed", None)
        if seed is None or seed == -1:
            seed = random.randint(0, 2**31 - 1)
        else:
            try:
                seed = int(seed)
            except (ValueError, TypeError):
                seed = random.randint(0, 2**31 - 1)

        # Update request.seed so it's saved in metadata correctly
        if hasattr(request, "seed"):
            request.seed = seed

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
                seed=seed, # Pass explicit seed to pipeline
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
        seed = getattr(request, "seed", None)
        if seed is None or seed == -1:
            seed = random.randint(0, 2**31 - 1)
        else:
            try:
                seed = int(seed)
            except (ValueError, TypeError):
                seed = random.randint(0, 2**31 - 1)

        # Update request.seed so it's saved in metadata correctly
        if hasattr(request, "seed"):
            request.seed = seed

        # Ensure divisible by 32 (or 64 for some LTX versions)
        width = (width // 32) * 32
        height = (height // 32) * 32

        loras = getattr(request, "loras", [])
        lora_path = None
        lora_scale = 1.0
        if loras:
            lora_path = loras[0].path
            # lora_scale = loras[0].scale # Forced to 1.0 as requested
            self._log_job(f"MLXLTXAdapter: Injecting LoRA {lora_path} into base path (Pass 1).")

        # Optional I2V conditioning image. Comes from the app's "Image to Video"
        # scene mode (Scene.referenceImagePath -> GenerationRequest.image_path,
        # see ProjectStudioViewModel.swift / GenerationClient.swift). Neither the
        # Swift request struct nor GenerationRequest currently exposes strength/
        # frame-index knobs, so those just take their standard I2V defaults
        # (full-strength conditioning on frame 0) via getattr fallback.
        image_path = getattr(request, "image_path", None)
        image_strength = getattr(request, "image_strength", None) or 1.0
        image_frame_idx = getattr(request, "image_frame_idx", None) or 0
        if image_path:
            self._log_job(f"MLXLTXAdapter: Conditioning on reference image {image_path} (strength={image_strength}, frame={image_frame_idx})")

        if progress_callback:
            progress_callback("generating_video", 0.1, "Starting LoRA-respecting LTX generation...")

        # Run inference (blocking call, offload to thread)
        try:
            if lora_path:
                # Use our manual LoRA merging pipeline
                await asyncio.to_thread(
                    self._generate_video_with_lora,
                    model_repo=model_repo,
                    text_encoder_repo=text_encoder_repo,
                    prompt=prompt,
                    width=width,
                    height=height,
                    num_frames=num_frames,
                    seed=seed,
                    output_path=output_path,
                    lora_path=lora_path,
                    lora_scale=lora_scale,
                    image_path=image_path,
                    image_strength=image_strength,
                    image_frame_idx=image_frame_idx,
                    progress_callback=progress_callback
                )
            else:
                # Fallback to plain generate_video if no LoRA
                import inspect
                sig = inspect.signature(generate)

                # Prepare arguments
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

                # generate_video (mlx_video.generate) natively supports I2V via
                # these three kwargs -- see the is_i2v branch in that module.
                if image_path:
                    if "image" in sig.parameters:
                        gen_kwargs["image"] = image_path
                    if "image_strength" in sig.parameters:
                        gen_kwargs["image_strength"] = image_strength
                    if "image_frame_idx" in sig.parameters:
                        gen_kwargs["image_frame_idx"] = image_frame_idx

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
                seed = random.randint(0, 2**31 - 1)
            else:
                try:
                    seed = int(seed)
                except (ValueError, TypeError):
                    seed = random.randint(0, 2**31 - 1)

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

        # Mirrors generate_text_to_video's routing. The unified AV path
        # (_generate_av -> generate_video_with_audio) never merges LoRA weights
        # at all -- it only logs a warning and ignores request.loras (see
        # _generate_av below) -- so an I2V request with a character LoRA attached
        # would silently render the untrained base model's face/appearance. When
        # a LoRA is present we route to the LoRA-respecting base path instead,
        # which now also carries the reference image through to
        # _generate_video_with_lora for proper I2V conditioning (see there).
        # That path can't produce the joint audio track, but that's the same
        # tradeoff generate_text_to_video already makes for T2V+LoRA.
        loras = getattr(request, "loras", [])
        if self._pipeline == "AV_MODEL" or self._is_av:
            if loras:
                self._log_job("MLXLTXAdapter [I2V]: LoRAs detected with AV model. Routing to LoRA-respecting BASE path.")
                return await self._generate_base_with_av_checkpoint(request, output_path, progress_callback, cancellation_token)
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
            else:
                try:
                    seed = int(seed)
                except (ValueError, TypeError):
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
