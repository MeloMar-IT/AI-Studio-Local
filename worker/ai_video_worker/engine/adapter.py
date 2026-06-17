from abc import ABC, abstractmethod
from typing import Any, List, Optional
from ai_video_worker.engine.base import ProgressCallback, CancellationToken

class LTXAdapter(ABC):
    """
    Interface for the MLX/LTX backend adapter.
    This decouples the GenerationEngine from specific library implementations.
    """

    @abstractmethod
    def capabilities(self) -> List[str]:
        """Returns a list of supported generation modes."""
        pass

    @abstractmethod
    async def load_model(self, model_profile: Any) -> Any:
        """Loads the model weights and prepares the pipeline."""
        pass

    @abstractmethod
    async def unload_model(self, model_id: str) -> None:
        """Unloads the model and frees resources."""
        pass

    @abstractmethod
    async def generate_text_to_video(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        """Executes text-to-video generation."""
        pass

    @abstractmethod
    async def generate_image_to_video(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        """Executes image-to-video generation."""
        pass

    @abstractmethod
    async def generate_audio_to_video(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        """Executes audio-to-video generation."""
        pass

    @abstractmethod
    async def generate_retake(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        """Executes video retake generation."""
        pass
