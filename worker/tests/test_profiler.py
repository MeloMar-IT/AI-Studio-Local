import pytest
from unittest.mock import patch, MagicMock
from ltx_worker.utils.profiler import get_hardware_profile

@pytest.fixture
def mock_system_info():
    with patch("platform.system") as mock_system, \
         patch("platform.node") as mock_node, \
         patch("platform.mac_ver") as mock_mac_ver, \
         patch("platform.python_version") as mock_py_ver, \
         patch("subprocess.check_output") as mock_subprocess, \
         patch("psutil.virtual_memory") as mock_mem, \
         patch("shutil.disk_usage") as mock_disk, \
         patch("shutil.which") as mock_which, \
         patch("ltx_worker.utils.profiler.is_mlx_available") as mock_mlx, \
         patch("ltx_worker.utils.profiler.is_pytorch_available") as mock_torch:

        mock_system.return_value = "Darwin"
        mock_node.return_value = "Test-Mac"
        mock_mac_ver.return_value = ("14.5", ("", "", ""), "")
        mock_py_ver.return_value = "3.11.0"
        mock_subprocess.return_value = b"Apple M2 Max"

        # 32GB total, 16GB free
        mem_mock = MagicMock()
        mem_mock.total = 32 * (1024**3)
        mem_mock.available = 16 * (1024**3)
        mock_mem.return_value = mem_mock

        # 100GB free
        disk_mock = MagicMock()
        disk_mock.free = 100 * (1024**3)
        mock_disk.return_value = disk_mock

        mock_which.return_value = "/usr/local/bin/ffmpeg"
        mock_mlx.return_value = True
        mock_torch.return_value = True

        yield {
            "system": mock_system,
            "subprocess": mock_subprocess,
            "mlx": mock_mlx,
            "which": mock_which,
            "disk": mock_disk,
            "mem": mock_mem
        }

def test_apple_silicon_ready(mock_system_info):
    profile = get_hardware_profile()
    assert profile["os_name"] == "Darwin"
    assert profile["status"] == "ready"
    assert "Apple" in profile["chip"]
    assert profile["mlx_available"] is True
    assert profile["ffmpeg_available"] is True

def test_unsupported_os(mock_system_info):
    mock_system_info["system"].return_value = "Windows"
    profile = get_hardware_profile()
    assert profile["status"] == "unsupported"
    assert any("macOS" in msg for msg in profile["messages"])

def test_intel_mac_warning(mock_system_info):
    mock_system_info["subprocess"].return_value = b"Intel(R) Core(TM) i9-9880H CPU @ 2.30GHz"
    profile = get_hardware_profile()
    assert profile["status"] == "unsupported" # Based on my logic: apple_silicon is required
    assert any("Apple Silicon" in msg for msg in profile["messages"])

def test_missing_mlx_warning(mock_system_info):
    mock_system_info["mlx"].return_value = False
    profile = get_hardware_profile()
    assert profile["status"] == "warning"
    assert any("MLX is not installed" in msg for msg in profile["messages"])

def test_missing_ffmpeg_warning(mock_system_info):
    mock_system_info["which"].return_value = None
    profile = get_hardware_profile()
    assert profile["status"] == "warning"
    assert any("ffmpeg is missing" in msg for msg in profile["messages"])

def test_low_memory_warning(mock_system_info):
    # Mock 8GB total memory
    mem_mock = MagicMock()
    mem_mock.total = 8 * (1024**3)
    mem_mock.available = 4 * (1024**3)
    mock_system_info["mem"].return_value = mem_mock

    profile = get_hardware_profile()
    assert profile["status"] == "warning"
    assert any("limited memory" in msg for msg in profile["messages"])

def test_low_disk_space_warning(mock_system_info):
    # Mock 5GB free disk space
    disk_mock = MagicMock()
    disk_mock.free = 5 * (1024**3)
    mock_system_info["disk"].return_value = disk_mock

    profile = get_hardware_profile()
    assert profile["status"] == "warning"
    assert any("Low disk space" in msg for msg in profile["messages"])
