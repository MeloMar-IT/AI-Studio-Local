from abc import ABC, abstractmethod
from typing import Any, Callable, Dict, Optional, Protocol
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
    async def generate(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        pass
