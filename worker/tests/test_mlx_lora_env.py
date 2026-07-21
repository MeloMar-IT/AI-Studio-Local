import pytest
import sys
import os
import json
import platform
import asyncio
from unittest.mock import MagicMock, patch, AsyncMock
from pathlib import Path
from ai_video_worker.engine.mlx_adapter import MLXLTXAdapter
from ai_video_worker.engine.base import UnsupportedCapabilityError, DependencyError

@pytest.fixture
def adapter():
    return MLXLTXAdapter()

@pytest.fixture
def mock_request():
    request = MagicMock()
    request.element_id = "test_element"
    request.model_id = "test_model"
    request.training_data_paths = ["/path/to/video1.mp4"]
    request.trigger_word = "test_trigger"
    request.steps = 10
    request.rank = 8
    request.learning_rate = 0.001
    return request

@pytest.mark.asyncio
async def test_train_lora_arm64_accepted(adapter, mock_request):
    with patch("sys.platform", "darwin"), \
         patch("platform.machine", return_value="arm64"), \
         patch("mlx.core", create=True), \
         patch("asyncio.create_subprocess_exec") as mock_exec, \
         patch("os.makedirs"), \
         patch("ai_video_worker.engine.mlx_adapter.glob.glob") as mock_glob, \
         patch("ai_video_worker.engine.mlx_adapter.os.path") as mock_path:

        mock_glob.return_value = ["/output/adapter.safetensors"]
        mock_path.exists.return_value = True
        mock_path.abspath.side_effect = lambda x: x
        mock_path.join.side_effect = os.path.join
        mock_path.dirname.side_effect = os.path.dirname

        mock_process = AsyncMock()
        mock_process.stdout.readline = AsyncMock(side_effect=[b"Training finished successfully.\n", b""])
        mock_process.wait = AsyncMock(return_value=0)
        mock_process.returncode = 0
        mock_exec.return_value = mock_process

        await adapter.train_lora(mock_request, "/output")

        # Verify it uses sys.executable and not uv
        args, kwargs = mock_exec.call_args
        assert args[0] == sys.executable
        assert "uv" not in args

@pytest.mark.asyncio
async def test_train_lora_x86_64_rejected(adapter, mock_request):
    with patch("sys.platform", "darwin"), \
         patch("platform.machine", return_value="x86_64"):

        with pytest.raises(UnsupportedCapabilityError) as excinfo:
            await adapter.train_lora(mock_request, "/output")

        assert "MLX training requires native Apple Silicon ARM64 Python" in str(excinfo.value)
        assert "x86_64" in str(excinfo.value)

@pytest.mark.asyncio
async def test_train_lora_universal2_arm64_accepted(adapter, mock_request):
    # sysconfig.get_platform() returning universal2 but platform.machine() is arm64
    with patch("sys.platform", "darwin"), \
         patch("platform.machine", return_value="arm64"), \
         patch("sysconfig.get_platform", return_value="macosx-10.13-universal2"), \
         patch("mlx.core", create=True), \
         patch("asyncio.create_subprocess_exec") as mock_exec, \
         patch("os.makedirs"), \
         patch("ai_video_worker.engine.mlx_adapter.glob.glob") as mock_glob, \
         patch("ai_video_worker.engine.mlx_adapter.os.path") as mock_path:

        mock_glob.return_value = ["/output/adapter.safetensors"]
        mock_path.exists.return_value = True
        mock_path.abspath.side_effect = lambda x: x
        mock_path.join.side_effect = os.path.join
        mock_path.dirname.side_effect = os.path.dirname

        mock_process = AsyncMock()
        mock_process.stdout.readline = AsyncMock(side_effect=[b"Training finished successfully.\n", b""])
        mock_process.wait = AsyncMock(return_value=0)
        mock_process.returncode = 0
        mock_exec.return_value = mock_process

        await adapter.train_lora(mock_request, "/output")
        assert mock_exec.called

@pytest.mark.asyncio
async def test_train_lora_missing_mlx_rejected(adapter, mock_request):
    with patch("sys.platform", "darwin"), \
         patch("platform.machine", return_value="arm64"):

        with patch.dict("sys.modules", {"mlx.core": None}):
            # We must make sure that it tries to import mlx.core and fails.
            # In my implementation it's 'try: import mlx.core'
            with patch("builtins.__import__", side_effect=ImportError):
                with pytest.raises(DependencyError) as excinfo:
                    await adapter.train_lora(mock_request, "/output")
                assert "MLX is not installed" in str(excinfo.value)

@pytest.mark.asyncio
async def test_train_lora_env_vars(adapter, mock_request):
    with patch("sys.platform", "darwin"), \
         patch("platform.machine", return_value="arm64"), \
         patch("mlx.core", create=True), \
         patch("asyncio.create_subprocess_exec") as mock_exec, \
         patch("os.makedirs"), \
         patch("ai_video_worker.engine.mlx_adapter.glob.glob") as mock_glob, \
         patch("ai_video_worker.engine.mlx_adapter.os.path") as mock_path:

        mock_glob.return_value = ["/output/adapter.safetensors"]
        mock_path.exists.return_value = True
        mock_path.abspath.side_effect = lambda x: x
        mock_path.join.side_effect = os.path.join
        mock_path.dirname.side_effect = os.path.dirname

        mock_process = AsyncMock()
        mock_process.stdout.readline = AsyncMock(side_effect=[b"Training finished successfully.\n", b""])
        mock_process.wait = AsyncMock(return_value=0)
        mock_process.returncode = 0
        mock_exec.return_value = mock_process

        # Mocking os.environ to have UV_PYTHON_PLATFORM
        with patch.dict("os.environ", {"UV_PYTHON_PLATFORM": "macos-x86_64", "PATH": "/usr/bin"}):
            await adapter.train_lora(mock_request, "/output")

            args, kwargs = mock_exec.call_args
            env = kwargs["env"]
            assert "UV_PYTHON_PLATFORM" not in env
            assert env["PYTHONUNBUFFERED"] == "1"
            assert "VIRTUAL_ENV" in env
            assert env["VIRTUAL_ENV"] in env["PATH"]
