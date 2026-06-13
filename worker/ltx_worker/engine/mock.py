import asyncio
import os
from typing import Any, List, Optional
from ltx_worker.engine.base import (
    GenerationEngine,
    ModelLoader,
    LoraLoader,
    MediaEncoder,
    ProgressCallback,
    CancellationToken,
)
from ltx_worker.logging_config import logger

class MockModelLoader(ModelLoader):
    async def load_model(self, model_id: str) -> Any:
        logger.info(f"Mock loading model: {model_id}")
        await asyncio.sleep(1)
        return {"model_id": model_id, "type": "mock"}

    async def unload_model(self, model_id: str) -> None:
        logger.info(f"Mock unloading model: {model_id}")
        await asyncio.sleep(0.5)

class MockLoraLoader(LoraLoader):
    async def load_lora(self, lora_path: str) -> Any:
        logger.info(f"Mock loading LoRA: {lora_path}")
        await asyncio.sleep(0.5)
        return {"lora_path": lora_path, "type": "mock"}

class MockMediaEncoder(MediaEncoder):
    async def encode_video(self, frames: Any, output_path: str, fps: int = 24) -> str:
        logger.info(f"Mock encoding video to: {output_path}")
        await asyncio.sleep(1)
        # Create a dummy file
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        with open(output_path, "wb") as f:
            f.write(b"mock video content")
        return output_path

class MockGenerationEngine(GenerationEngine):
    def __init__(
        self,
        model_loader: ModelLoader,
        lora_loader: LoraLoader,
        media_encoder: MediaEncoder,
    ):
        self.model_loader = model_loader
        self.lora_loader = lora_loader
        self.media_encoder = media_encoder

    def capabilities(self) -> List[str]:
        return ["text-to-video", "image-to-video", "audio-to-video", "retake"]

    async def load_model(self, model_profile: Any) -> Any:
        model_id = getattr(model_profile, "id", str(model_profile))
        return await self.model_loader.load_model(model_id)

    async def unload_model(self, model_id: str) -> None:
        await self.model_loader.unload_model(model_id)

    async def generate_text_to_video(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        return await self.generate(request, output_path, progress_callback, cancellation_token)

    async def generate_image_to_video(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        return await self.generate(request, output_path, progress_callback, cancellation_token)

    async def generate_audio_to_video(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        return await self.generate(request, output_path, progress_callback, cancellation_token)

    async def generate_retake(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        return await self.generate(request, output_path, progress_callback, cancellation_token)

    async def generate(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        stages = [
            ("checking_hardware", 0.1, "Checking hardware compatibility..."),
            ("loading_model", 0.2, "Loading LTX model into memory..."),
            ("preparing_inputs", 0.3, "Preparing generation inputs..."),
            ("generating_video", 0.4, "Generating video frames (this may take a while)..."),
            ("generating_video", 0.7, "Finishing video generation..."),
            ("encoding_output", 0.9, "Encoding final MP4..."),
        ]

        if getattr(request, "image_path", None):
            logger.info(f"Mock image-to-video using image: {request.image_path}")
            stages.insert(3, ("processing_image", 0.35, "Processing input image..."))

        for status, progress, message in stages:
            if progress_callback:
                progress_callback(status, progress, message)

            # Check for cancellation before sleep
            if cancellation_token and cancellation_token.is_cancelled:
                logger.info("Generation cancelled")
                return ""

            # If environment is production, we MUST NOT use mock generation.
            from ltx_worker.config import settings
            if settings.environment == "production":
                 raise RuntimeError("❌ PRODUCTION SECURITY VIOLATION: Mock generation executed in production mode.")

            # await asyncio.sleep(0.5) # Revert to balanced sleep
            # Speed up tests
            if settings.environment != "test":
                await asyncio.sleep(0.5)
            # No sleep in test mode to pass tests quickly
            else:
                await asyncio.sleep(0) # Minimal yield

            if status == "loading_model":
                await self.model_loader.load_model(getattr(request, "model_id", "default"))
            elif status == "encoding_output":
                await self.media_encoder.encode_video(None, output_path)

        if progress_callback:
            progress_callback("completed", 1.0, "Generation completed successfully.")

        return output_path
