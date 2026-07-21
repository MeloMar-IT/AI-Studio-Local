import asyncio
import json
import os
import platform
import re
import subprocess
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
    Consolidated LTX generation engine that directly manages MLX/LTX generation.
    Simplified to prioritize the working real implementation.
    """

    def __init__(self, adapter: Optional[LTXAdapter] = None):
        if adapter is None:
            # We still use MLXLTXAdapter but we've simplified its role
            from ai_video_worker.engine.mlx_adapter import MLXLTXAdapter
            self.adapter = MLXLTXAdapter()
        else:
            self.adapter = adapter

        logger.info(f"Initialized LTXGenerationEngine with adapter: {self.adapter.__class__.__name__}")
        # Track active models and hardware state directly if needed
        self._current_model_id = None
        self._job_logger = None

    def set_job_logger(self, job_logger: Optional[Any]) -> None:
        self._job_logger = job_logger
        if hasattr(self.adapter, "set_job_logger"):
             self.adapter.set_job_logger(job_logger)

    def _log_job(self, message: str):
        if self._job_logger:
            try:
                self._job_logger(message)
            except Exception:
                pass
        logger.info(message)

    def _extract_dialogue(self, prompt: str) -> Optional[str]:
        """
        Extracts spoken dialogue from a prompt.
        Pattern: "says:", "shouts:", "whispers:" etc. followed by text in quotes.
        Or just text in double quotes if it looks like dialogue.
        """
        # Search for pattern: something like 'says: "Hi, I am Marcel."'
        dialogue_match = re.search(r'(?:says|shouts|whispers|speaks|voices|mentions|tells|asks):\s*"([^"]+)"', prompt, re.IGNORECASE)
        if dialogue_match:
            return dialogue_match.group(1)

        # Fallback: look for any double quotes that contain a sentence-like structure
        quotes_match = re.findall(r'"([^"]{3,})"', prompt)
        if quotes_match:
            # Return the longest quoted string as it's most likely the dialogue
            return max(quotes_match, key=len)

        return None

    def _strip_dialogue(self, prompt: str) -> str:
        """
        Removes dialogue from the prompt so it doesn't trigger the unified AV path.
        """
        # Remove the dialogue pattern
        stripped = re.sub(r'(?:says|shouts|whispers|speaks|voices|mentions|tells|asks):\s*"[^"]+"', '', prompt, flags=re.IGNORECASE)
        # Remove any remaining quoted text that looks like dialogue
        stripped = re.sub(r'"[^"]{3,}"', '', stripped)
        # Clean up extra whitespace
        stripped = re.sub(r'\s+', ' ', stripped).strip()
        return stripped

    def capabilities(self) -> List[str]:
        return self.adapter.capabilities()

    async def load_model(self, model_profile: Any) -> Any:
        model_id = getattr(model_profile, "id", str(model_profile))
        self._log_job(f"LTXEngine: Loading model {model_id}")

        # In testing/mock environments, we might not want to check for real model paths
        if os.environ.get("LTX_MOCK_MODEL", "0") == "1":
            return await self.adapter.load_model(model_profile)

        # Ensure hardware is ready
        self._validate_hardware()

        result = await self.adapter.load_model(model_profile)
        self._current_model_id = model_id
        return result

    async def unload_model(self, model_id: str) -> None:
        self._log_job(f"LTXEngine: Unloading model {model_id}")
        await self.adapter.unload_model(model_id)
        if self._current_model_id == model_id:
            self._current_model_id = None

    async def generate_text_to_video(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        return await self._run_generation(
            "text-to-video",
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
            "image-to-video",
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
            "audio-to-video",
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
            "retake",
            request,
            output_path,
            progress_callback,
            cancellation_token
        )

    async def generate_voice_clone(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        """
        Generates a voice clone (TTS with reference audio).
        """
        # If we have an audio-capable adapter, use it
        if hasattr(self.adapter, "generate_voice_clone"):
            return await self.adapter.generate_voice_clone(
                request,
                output_path,
                progress_callback,
                cancellation_token
            )

        # Fallback/Default implementation if not in adapter yet
        self._log_job("LTXEngine: Voice clone requested")
        if progress_callback:
            progress_callback("preparing_voice_clone", 0.1, "Initializing voice cloning model...")

        # In a real implementation, we would load the F5-TTS or similar model here
        # For now, we'll use the adapter if it supports it or raise error
        raise UnsupportedCapabilityError("voice_clone", "Current adapter does not support standalone voice cloning.")

    async def train_lora(
        self,
        request: Any,
        output_directory: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        """
        Trains a LoRA for a specific character or element.
        """
        self._log_job(f"LTXEngine: Starting LoRA training for element {getattr(request, 'element_id', 'unknown')}")

        if progress_callback:
            progress_callback("training_lora", 0.05, "Initializing training environment...")

        # If the adapter supports it, use it
        try:
            # Check if adapter has the method
            if hasattr(self.adapter, "train_lora") and "lora-training" in self.adapter.capabilities():
                return await self.adapter.train_lora(
                    request,
                    output_directory,
                    progress_callback,
                    cancellation_token
                )
            else:
                raise UnsupportedCapabilityError("lora-training")
        except (UnsupportedCapabilityError, AttributeError):
            # Fallback to mock implementation ONLY if explicitly allowed by config
            if settings.allow_mock_lora_training:
                self._log_job("LTXEngine: [MOCK] Adapter does not support train_lora, falling back to mock as allowed by config")
            else:
                self._log_job(f"LTXEngine: ERROR: Adapter {self.adapter.__class__.__name__} does not implement train_lora. Cannot train real LoRA.")
                raise UnsupportedCapabilityError("lora-training", f"Current adapter {self.adapter.__class__.__name__} does not support LoRA training. Configure a training-capable adapter or explicitly enable mock mode.")

        # If we reach here, we are in MOCK mode
        total_steps = getattr(request, "steps", 500)
        for i in range(1, total_steps + 1):
            if cancellation_token and cancellation_token.is_cancelled:
                self._log_job("LTXEngine: [MOCK] LoRA training cancelled")
                return ""

            if i % 50 == 0 or i == 1:
                progress = 0.05 + (0.90 * (i / total_steps))
                if progress_callback:
                    progress_callback("training_lora", progress, f"[MOCK] Training step {i}/{total_steps}...")
                await asyncio.sleep(0.1) # Simulate work

        if progress_callback:
            progress_callback("saving_metadata", 0.95, "[MOCK] Saving mock LoRA weights...")

        # Create a dummy LoRA file
        os.makedirs(output_directory, exist_ok=True)
        lora_filename = f"{getattr(request, 'element_id', 'element')}_lora_MOCK.safetensors"
        lora_path = os.path.join(output_directory, lora_filename)
        with open(lora_path, "w") as f:
            # Write more than 17 bytes to pass the basic size check if needed,
            # but keep the marker for explicit detection.
            f.write("MOCK_LORA_WEIGHTS" + " " * 100)

        self._log_job(f"LTXEngine: [MOCK] LoRA training completed. Mock weights at {lora_path}")
        return lora_path

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

    async def _run_two_pass_generation(
        self,
        dialogue: str,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        """
        Two-pass pipeline to work around missing LoRA support in unified AV path.
        Pass 1: Silent video with LoRA.
        Pass 2: TTS and Muxing.
        """
        job_id = os.path.basename(os.path.dirname(output_path))
        start_time = time.time()

        # --- PASS 1: SILENT VIDEO ---
        self._log_job(f"LTXEngine [Pass 1]: Starting silent video generation with LoRA.")
        if progress_callback:
            progress_callback("generating_video", 0.1, "Pass 1/2: Generating character-faithful video (LoRA)...")

        # 1. Prepare stripped request
        original_prompt = getattr(request, "prompt", "")
        original_composed = getattr(request, "composed_prompt", None)
        original_model_id = getattr(request, "model_id", settings.default_model_id)

        stripped_prompt = self._strip_dialogue(original_prompt)
        stripped_composed = self._strip_dialogue(original_composed) if original_composed else None

        self._log_job(f"LTXEngine [Pass 1]: Stripped prompt: '{stripped_prompt}'")

        # Create a modified request for Pass 1
        # We can now use the SAME model ID because the adapter has been updated
        # to handle LoRAs by routing to the base path even for AV models.
        pass1_model_id = original_model_id

        request.prompt = stripped_prompt
        if original_composed:
            request.composed_prompt = stripped_composed
        request.model_id = pass1_model_id

        # Temporarily ensure adapter knows it's an AV model but we want base path
        # (The adapter.generate_text_to_video will now handle this based on loras presence)
        was_av = self.adapter._is_av
        # We DON'T set self.adapter._is_av = False anymore because we WANT the adapter
        # to recognize it's an AV model and use _generate_base_with_av_checkpoint.

        try:
            # 2. Ensure model is loaded
            if self.adapter._current_model_id != pass1_model_id:
                self._log_job(f"LTXEngine [Pass 1]: Loading model {pass1_model_id} (LoRA-respecting path will be used).")
                await self.load_model(pass1_model_id)

            # 3. Generate silent video
            silent_output_path = output_path.replace(".mp4", "_silent.mp4")

            # Update progress callback for Pass 1 (0.1 to 0.7)
            def pass1_progress(status, progress, message):
                if progress_callback:
                    mapped_progress = 0.1 + (progress * 0.6)
                    progress_callback("generating_video", mapped_progress, f"Pass 1/2: {message}")

            await self.adapter.generate_text_to_video(
                request,
                silent_output_path,
                pass1_progress,
                cancellation_token
            )

            if cancellation_token and cancellation_token.is_cancelled:
                return ""

            if not os.path.exists(silent_output_path):
                raise RuntimeError("Pass 1: Silent video generation failed to produce output.")

            self._log_job(f"LTXEngine [Pass 1]: Silent video generated at {silent_output_path}")

            # --- PASS 2: AUDIO & MUXING ---
            self._log_job(f"LTXEngine [Pass 2]: Generating audio and muxing.")
            if progress_callback:
                progress_callback("generating_audio", 0.75, "Pass 2/2: Generating speech...")

            # 1. Generate Audio (TTS)
            # Use original prompt for dialogue extraction
            audio_output_path = os.path.join(os.path.dirname(output_path), "speech.wav")

            # Update request for Pass 2 (audio focus)
            request.prompt = dialogue # Pass only the dialogue to TTS
            # If there was a voice clone ref, it will be used by generate_voice_clone
            await self.generate_voice_clone(request, audio_output_path, None, cancellation_token)

            if cancellation_token and cancellation_token.is_cancelled:
                return ""

            if not os.path.exists(audio_output_path):
                self._log_job("LTXEngine [Pass 2]: WARNING: Audio generation failed, falling back to silent video.")
                os.rename(silent_output_path, output_path)
            else:
                self._log_job(f"LTXEngine [Pass 2]: Audio generated at {audio_output_path}")

                # 2. Muxing with FFmpeg
                if progress_callback:
                    progress_callback("muxing", 0.85, "Pass 2/2: Combining video and speech...")

                muxed_output_path = output_path
                try:
                    # Using ffmpeg to combine Pass 1 video and Pass 2 audio
                    # -i video -i audio -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 -shortest
                    cmd = [
                        "ffmpeg", "-y",
                        "-i", silent_output_path,
                        "-i", audio_output_path,
                        "-c:v", "copy",
                        "-c:a", "aac",
                        "-map", "0:v:0",
                        "-map", "1:a:0",
                        "-shortest",
                        muxed_output_path
                    ]
                    self._log_job(f"LTXEngine [Pass 2]: Running ffmpeg: {' '.join(cmd)}")
                    subprocess.run(cmd, check=True, capture_output=True)
                    self._log_job(f"LTXEngine [Pass 2]: Muxing complete.")
                except Exception as e:
                    self._log_job(f"LTXEngine [Pass 2]: FFmpeg muxing failed: {e}. Falling back to silent video.")
                    if os.path.exists(silent_output_path):
                        os.rename(silent_output_path, output_path)

            # 3. Clean up temporary files
            try:
                if os.path.exists(silent_output_path) and silent_output_path != output_path:
                    os.remove(silent_output_path)
                if os.path.exists(audio_output_path):
                    os.remove(audio_output_path)
            except Exception as e:
                logger.warning(f"Failed to cleanup temp files: {e}")

            # 4. Final steps (Preview, metadata)
            if progress_callback:
                progress_callback("saving_metadata", 0.95, "Finalizing output...")

            # Extract preview using adapter's method
            if hasattr(self.adapter, "_extract_preview"):
                self.adapter._extract_preview(output_path)

            self._log_job(f"LTXEngine: Two-pass generation finished in {time.time() - start_time:.2f}s")
            return output_path

        finally:
            # Restore state
            if 'was_av' in locals():
                self.adapter._is_av = was_av
            # Restore original request fields
            request.prompt = original_prompt
            if original_composed:
                request.composed_prompt = original_composed
            request.model_id = original_model_id

    async def _run_generation(
        self,
        mode: str,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        job_id = os.path.basename(os.path.dirname(output_path))
        start_time = time.time()

        self._log_job(f"LTXEngine: Starting {mode} generation for job {job_id}")

        prompt = getattr(request, "prompt", "N/A")
        if hasattr(request, "composed_prompt") and request.composed_prompt:
             prompt = request.composed_prompt
        self._log_job(f"LTXEngine: Request prompt: '{prompt}'")

        loras = getattr(request, "loras", []) or []
        if loras:
            lora_info = ", ".join([f"{l.path} (scale: {l.scale})" for l in loras])
            self._log_job(f"LTXEngine: Using LoRAs: {lora_info}")

        # Check for dialogue to determine if we need two-pass generation
        # This is needed because unified AV generation currently ignores LoRAs.
        dialogue = self._extract_dialogue(prompt)
        has_lora = (len(loras) > 0 or getattr(request, "lora_path", None))

        # Security check: refuse MOCK loras in production unless explicitly allowed
        if has_lora:
            all_lora_paths = [l.path for l in loras]
            if getattr(request, "lora_path", None):
                all_lora_paths.append(request.lora_path)

            for lp in all_lora_paths:
                if lp and "_MOCK" in lp and not settings.allow_mock_lora_training:
                    self._log_job(f"LTXEngine: ERROR: Refusing to use mock LoRA file {lp} in generation. Mock LoRA usage is disabled.")
                    raise ValueError(f"Mock LoRA file detected and AI_VIDEO_WORKER_ALLOW_MOCK_LORA_TRAINING is False. Path: {lp}")

        # If it's an AV model, we check if we should use two-pass.
        # Two-pass is only strictly required if we have BOTH dialogue AND LoRAs.
        # If we only have LoRAs and NO dialogue, MLXAdapter will now correctly
        # route to the silent base path.
        # We also use two-pass if it's NOT an AV model but has dialogue,
        # as non-AV models can't generate audio themselves.
        is_av_model = "av" in getattr(request, "model_id", "").lower()

        use_two_pass = bool(dialogue) and (bool(has_lora) or not is_av_model)

        if use_two_pass:
            if bool(dialogue) and bool(has_lora) and is_av_model:
                 self._log_job(f"LTXEngine: DETECTED DIALOGUE + LoRA with AV model. Using two-pass generation (Pass 1: Video+LoRA, Pass 2: TTS+Mux).")
            elif bool(dialogue) and not is_av_model:
                 self._log_job(f"LTXEngine: DETECTED DIALOGUE with non-AV model. Using two-pass generation (Pass 1: Video, Pass 2: TTS+Mux).")

            self._log_job(f"LTXEngine: Extracted dialogue: '{dialogue}'")
            return await self._run_two_pass_generation(
                dialogue,
                request,
                output_path,
                progress_callback,
                cancellation_token
            )

        try:
            # 0. Voice Clone Pre-processing
            voice_clone_ref = getattr(request, "voice_clone_reference_path", None)
            if voice_clone_ref and os.path.exists(voice_clone_ref):
                self._log_job(f"LTXEngine: Voice clone reference detected: {voice_clone_ref}")
                if progress_callback:
                    progress_callback("generating_audio", 0.02, "Generating cloned voice...")

                # Generate audio path for the cloned voice
                cloned_audio_path = os.path.join(os.path.dirname(output_path), "cloned_voice.wav")

                # We use the same engine but specifically for voice clone
                # This allows us to use f5-tts-mlx or similar
                await self.generate_voice_clone(request, cloned_audio_path, progress_callback, cancellation_token)

                # Update request to use the generated audio
                if hasattr(request, "audio_path"):
                    request.audio_path = cloned_audio_path
                    self._log_job(f"LTXEngine: Cloned voice generated at {cloned_audio_path}, using as audio_path")

            # 1. Automatic Model Loading
            model_id = getattr(request, "model_id", settings.default_model_id)
            if self.adapter._current_model_id != model_id:
                if progress_callback:
                    progress_callback("loading_model", 0.05, f"Switching to model {model_id}...")

                from ai_video_worker.utils.models import scan_models
                models = scan_models(settings.models_dir)
                profile = next((m for m in models if m.id == model_id), None)

                # Ensure we pass the profile if found, otherwise the ID
                await self.load_model(profile if profile is not None else model_id)
            elif not self.adapter._pipeline:
                # If ID matches but pipeline is gone, reload
                if progress_callback:
                    progress_callback("loading_model", 0.05, f"Reloading model {model_id}...")

                from ai_video_worker.utils.models import scan_models
                models = scan_models(settings.models_dir)
                profile = next((m for m in models if m.id == model_id), None)
                await self.load_model(profile if profile is not None else model_id)

            # 2. Execution
            if progress_callback:
                progress_callback("preparing_inputs", 0.1, "Preparing generation inputs...")

            # Select adapter method based on mode
            adapter_methods = {
                "text-to-video": self.adapter.generate_text_to_video,
                "image-to-video": self.adapter.generate_image_to_video,
                "audio-to-video": self.adapter.generate_audio_to_video,
                "retake": self.adapter.generate_retake
            }

            method = adapter_methods.get(mode)
            if not method:
                raise UnsupportedCapabilityError(mode)

            result_path = await method(
                request,
                output_path,
                progress_callback,
                cancellation_token
            )

            if cancellation_token and cancellation_token.is_cancelled:
                logger.info(f"Generation for job {job_id} was cancelled.")
                return ""

            # 3. Preview Generation
            logger.debug(f"Generation finished in {time.time() - start_time:.2f}s, starting post-processing for job {job_id}")
            self._log_job(f"LTXEngine: Generation finished in {time.time() - start_time:.2f}s")
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

            # Use request prompt as composed prompt for now (until we have a real composer)
            composed_prompt = getattr(request, "prompt", "")
            self._log_job(f"LTXEngine: Saving composed prompt to file: '{composed_prompt}'")

            prompt_path = Path(output_path).parent / "composed-prompt.md"
            with open(prompt_path, "w") as f:
                f.write(f"# Composed Prompt\n\n{composed_prompt}\n")

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
        self._log_job(f"[_validate_hardware] Checking hardware compatibility. min_memory_gb={settings.min_memory_gb}")
        # Check for Apple Silicon
        if platform.machine() != "arm64":
            self._log_job("Not running on Apple Silicon. MLX might be slow or unsupported.")

        # Try to check for LTX dependencies in a way that doesn't block the whole engine
        try:
            import importlib
            importlib.import_module("ltx_video")
        except ImportError:
            # We don't raise DependencyError here anymore, let the adapter handle it
            # so it can fall back to mock if needed.
            self._log_job("ltx_video not found during hardware validation. Adapter will handle fallback.")

        # Check memory
        mem = psutil.virtual_memory()
        total_gb = mem.total / (1024**3)
        available_gb = mem.available / (1024**3)
        self._log_job(f"[_validate_hardware] Total RAM: {total_gb:.2f}GB, Available RAM: {available_gb:.2f}GB")
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
            "composed_prompt": req_data.get("composed_prompt") or req_data.get("prompt"),
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
            "reference_image_paths": req_data.get("reference_image_paths"),
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
