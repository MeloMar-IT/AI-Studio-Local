from abc import ABC, abstractmethod
from typing import Any, Callable, Dict, List, Optional, Protocol, Union
from pydantic import BaseModel

class ProgressCallback(Protocol):
    def __call__(self, status: str, progress: float, message: str) -> None:
        ...

class CancellationToken:
    def __init__(self):
        self._cancelled = False

    def cancel(self):
        self._cancelled = True

    @property
    def is_cancelled(self) -> bool:
        return self._cancelled

class UnsupportedCapabilityError(Exception):
    """Raised when the engine does not support a requested capability."""
    def __init__(self, capability: str, message: str = None):
        self.capability = capability
        self.message = message or f"Capability '{capability}' is not supported by the current engine."
        super().__init__(self.message)

class DependencyError(Exception):
    """Raised when a required dependency is missing."""
    def __init__(self, dependency: str, action: str):
        self.dependency = dependency
        self.action = action
        self.message = f"Missing dependency: {dependency}. {action}"
        super().__init__(self.message)

class ModelLoader(ABC):
    @abstractmethod
    async def load_model(self, model_id: str) -> Any:
        pass

    @abstractmethod
    async def unload_model(self, model_id: str) -> None:
        pass

class LoraLoader(ABC):
    @abstractmethod
    async def load_lora(self, lora_path: str) -> Any:
        pass

class MediaEncoder(ABC):
    @abstractmethod
    async def encode_video(self, frames: Any, output_path: str, fps: int = 24) -> str:
        pass

class GenerationEngine(ABC):
    @abstractmethod
    def capabilities(self) -> List[str]:
        """Returns a list of supported generation modes."""
        pass

    @abstractmethod
    async def load_model(self, model_profile: Any) -> Any:
        pass

    @abstractmethod
    async def unload_model(self, model_id: str) -> None:
        pass

    @abstractmethod
    async def generate_text_to_video(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        pass

    @abstractmethod
    async def generate_image_to_video(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        pass

    @abstractmethod
    async def generate_audio_to_video(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        pass

    @abstractmethod
    async def generate_retake(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        pass

    @abstractmethod
    async def generate(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        """Deprecated: Use specific generate_* methods instead."""
        pass
