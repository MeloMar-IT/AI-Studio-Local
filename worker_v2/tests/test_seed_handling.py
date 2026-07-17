import pytest
from unittest.mock import MagicMock, patch, AsyncMock
import os
import random
from ai_video_worker.engine.mlx_adapter import MLXLTXAdapter

@pytest.mark.asyncio
async def test_seed_generation_if_none():
    adapter = MLXLTXAdapter()

    # Mock pipeline and other dependencies
    adapter._pipeline = MagicMock()

    request = MagicMock()
    request.seed = None
    request.prompt = "A test prompt"

    # Mocking necessary imports inside generate_text_to_video
    with patch("ai_video_worker.engine.mlx_adapter.logger"):
        # We need to mock the pipeline call
        adapter._pipeline.return_value = "dummy_output.mp4"

        # We mock os.path.exists and shutil.copy for the output handling part
        with patch("os.path.exists", return_value=True), \
             patch("shutil.copy"):

            await adapter.generate_text_to_video(request, "output.mp4")

    # Verify that request.seed was updated to an integer
    assert isinstance(request.seed, int)
    assert 0 <= request.seed <= 2**32 - 1

    # Verify it was passed to the pipeline
    adapter._pipeline.assert_called_once()
    args, kwargs = adapter._pipeline.call_args
    assert kwargs["seed"] == request.seed

@pytest.mark.asyncio
async def test_seed_preserved_if_provided():
    adapter = MLXLTXAdapter()
    adapter._pipeline = MagicMock()

    request = MagicMock()
    request.seed = 12345
    request.prompt = "A test prompt"

    with patch("ai_video_worker.engine.mlx_adapter.logger"), \
         patch("os.path.exists", return_value=True), \
         patch("shutil.copy"):

            await adapter.generate_text_to_video(request, "output.mp4")

    assert request.seed == 12345
    adapter._pipeline.assert_called_once()
    args, kwargs = adapter._pipeline.call_args
    assert kwargs["seed"] == 12345
