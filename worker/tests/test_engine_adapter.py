import pytest
from unittest.mock import MagicMock, patch
from ai_video_worker.engine.mlx_adapter import MLXLTXAdapter
from ai_video_worker.engine.base import UnsupportedCapabilityError, DependencyError
from ai_video_worker.engine.ltx import LTXGenerationEngine

@pytest.mark.asyncio
async def test_adapter_capabilities():
    adapter = MLXLTXAdapter()
    caps = adapter.capabilities()
    assert "text-to-video" in caps
    assert "image-to-video" in caps
    # retake and audio-to-video might not be in the initial real adapter
    # but for this test we just ensure we get a list

@pytest.mark.asyncio
async def test_missing_dependency_error():
    adapter = MLXLTXAdapter()

    # Mock importlib.import_module to raise ImportError for mlx
    with patch("importlib.import_module", side_effect=ImportError("No module named 'mlx'")):
        with pytest.raises(DependencyError) as excinfo:
            await adapter.generate_text_to_video(MagicMock(), "path/to/output")
        assert "mlx" in str(excinfo.value)
        assert "pip install mlx" in excinfo.value.action

@pytest.mark.asyncio
async def test_unsupported_capability_error():
    adapter = MLXLTXAdapter()

    # generate_audio_to_video should raise UnsupportedCapabilityError
    with pytest.raises(UnsupportedCapabilityError) as excinfo:
        await adapter.generate_audio_to_video(MagicMock(), "path/to/output")
    assert "audio-to-video" in str(excinfo.value)

@pytest.mark.asyncio
async def test_engine_delegates_to_adapter(tmp_path):
    mock_adapter = MagicMock()
    mock_adapter.capabilities.return_value = ["text-to-video"]

    # Setup tmp output path
    output_dir = tmp_path / "job1"
    output_dir.mkdir()
    output_file = output_dir / "output.mp4"

    # Create an AsyncMock for the generate method
    from unittest.mock import AsyncMock
    mock_adapter.generate_text_to_video = AsyncMock(return_value=str(output_file))

    engine = LTXGenerationEngine(adapter=mock_adapter)

    assert engine.capabilities() == ["text-to-video"]

    request = MagicMock()
    request.model_dump.return_value = {"prompt": "test"}

    # Mock the internal _validate_hardware to avoid failing on non-Mac
    with patch.object(LTXGenerationEngine, "_validate_hardware"):
        await engine.generate_text_to_video(request, str(output_file))

    mock_adapter.generate_text_to_video.assert_called_once()

    # Verify metadata was saved
    assert (output_dir / "metadata.json").exists()

def test_api_does_not_import_mlx_directly():
    # This is a static check
    import ai_video_worker.api as api

    # Check if 'mlx' or 'mlx.core' is in sys.modules after importing api
    # (Note: this might be tricky if other things import it, but it's a start)
    import sys
    # We expect 'mlx' not to be in sys.modules if it wasn't there before
    # or at least not imported by api.py
    # A better way is to read the file content
    import os
    api_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "ai_video_worker", "api.py")
    with open(api_path, "r") as f:
        content = f.read()
        assert "import mlx" not in content
        assert "from mlx" not in content
