import pytest
from unittest.mock import MagicMock, patch, AsyncMock
import os
import random
import sys
from ai_video_worker.engine.mlx_adapter import MLXLTXAdapter

# Create a mock module for ltx_video
ltx_video_mock = MagicMock()
sys.modules["ltx_video"] = ltx_video_mock
sys.modules["ltx_video.utils"] = MagicMock()
sys.modules["ltx_video.utils.export_video"] = MagicMock()

@pytest.mark.asyncio
async def test_seed_generation_if_none():
    adapter = MLXLTXAdapter()

    # Mock pipeline and other dependencies
    adapter._pipeline = MagicMock()

    request = MagicMock()
    request.seed = None
    request.prompt = "A test prompt"

    # Mocking necessary imports inside generate_text_to_video
    with patch("ai_video_worker.engine.mlx_adapter.logger"), \
         patch("ai_video_worker.engine.mlx_adapter.importlib.import_module"), \
         patch("ai_video_worker.engine.mlx_adapter.export_to_video", create=True):
        # We need to mock the pipeline call
        mock_output = MagicMock()
        mock_output.frames = [MagicMock()]
        adapter._pipeline.return_value = mock_output

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
         patch("ai_video_worker.engine.mlx_adapter.importlib.import_module"), \
         patch("ai_video_worker.engine.mlx_adapter.export_to_video", create=True), \
         patch("os.path.exists", return_value=True), \
         patch("shutil.copy"):
            mock_output = MagicMock()
            mock_output.frames = [MagicMock()]
            adapter._pipeline.return_value = mock_output

            await adapter.generate_text_to_video(request, "output.mp4")

    assert request.seed == 12345
    adapter._pipeline.assert_called_once()
    args, kwargs = adapter._pipeline.call_args
    assert kwargs["seed"] == 12345

@pytest.mark.asyncio
async def test_seed_conversion_if_string():
    adapter = MLXLTXAdapter()
    adapter._pipeline = MagicMock()

    request = MagicMock()
    request.seed = "54321"
    request.prompt = "A test prompt"

    with patch("ai_video_worker.engine.mlx_adapter.logger"), \
         patch("ai_video_worker.engine.mlx_adapter.importlib.import_module"), \
         patch("ai_video_worker.engine.mlx_adapter.export_to_video", create=True), \
         patch("os.path.exists", return_value=True), \
         patch("shutil.copy"):
            mock_output = MagicMock()
            mock_output.frames = [MagicMock()]
            adapter._pipeline.return_value = mock_output

            await adapter.generate_text_to_video(request, "output.mp4")

    assert request.seed == 54321
    assert isinstance(request.seed, int)
    adapter._pipeline.assert_called_once()
    args, kwargs = adapter._pipeline.call_args
    assert kwargs["seed"] == 54321

@pytest.mark.asyncio
async def test_seed_fallback_if_invalid_string():
    adapter = MLXLTXAdapter()
    adapter._pipeline = MagicMock()

    request = MagicMock()
    request.seed = "not_a_number"
    request.prompt = "A test prompt"

    with patch("ai_video_worker.engine.mlx_adapter.logger"), \
         patch("ai_video_worker.engine.mlx_adapter.importlib.import_module"), \
         patch("ai_video_worker.engine.mlx_adapter.export_to_video", create=True), \
         patch("os.path.exists", return_value=True), \
         patch("shutil.copy"):
            mock_output = MagicMock()
            mock_output.frames = [MagicMock()]
            adapter._pipeline.return_value = mock_output

            await adapter.generate_text_to_video(request, "output.mp4")

    assert isinstance(request.seed, int)
    adapter._pipeline.assert_called_once()
    args, kwargs = adapter._pipeline.call_args
    assert kwargs["seed"] == request.seed
