from typing import Any, Optional
from ltx_worker.engine.base import (
    GenerationEngine,
    ProgressCallback,
    CancellationToken,
)

class LTXGenerationEngine(GenerationEngine):
    async def generate(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        raise NotImplementedError("Real LTX generation is not implemented yet.")
