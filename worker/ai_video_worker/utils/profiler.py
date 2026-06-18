import platform
import shutil
import subprocess
import os
import psutil
from typing import List, Tuple
from ai_video_worker.config import settings

def get_macos_version() -> str:
    return platform.mac_ver()[0]

def is_apple_silicon() -> bool:
    if platform.system() != "Darwin":
        return False
    # Check processor architecture
    cpu_info = subprocess.check_output(["sysctl", "-n", "machdep.cpu.brand_string"]).decode("utf-8")
    return "Apple" in cpu_info

def get_cpu_info() -> str:
    try:
        if platform.system() == "Darwin":
            return subprocess.check_output(["sysctl", "-n", "machdep.cpu.brand_string"]).decode("utf-8").strip()
        return platform.processor()
    except Exception:
        return platform.processor()

def get_total_memory_gb() -> float:
    return round(psutil.virtual_memory().total / (1024**3), 2)

def get_free_memory_gb() -> float:
    return round(psutil.virtual_memory().available / (1024**3), 2)

def get_free_disk_space_gb(path: str) -> float:
    try:
        # Ensure path exists for disk_usage to work
        if not os.path.exists(path):
            os.makedirs(path, exist_ok=True)
        usage = shutil.disk_usage(path)
        return round(usage.free / (1024**3), 2)
    except Exception:
        return 0.0

def is_mlx_available() -> bool:
    try:
        import mlx.core
        return True
    except ImportError:
        return False

def is_pytorch_available() -> bool:
    try:
        import torch
        return True
    except ImportError:
        return False

def is_ffmpeg_available() -> bool:
    return shutil.which("ffmpeg") is not None

def get_hardware_profile():
    os_name = platform.system()
    os_version = get_macos_version()
    chip = get_cpu_info()
    apple_silicon = is_apple_silicon()
    total_mem = get_total_memory_gb()
    free_mem = get_free_memory_gb()

    # Use absolute paths for disk check if possible, relative to project root
    models_path = os.path.abspath(settings.models_dir)
    outputs_path = os.path.abspath(settings.output_dir)

    free_disk_models = get_free_disk_space_gb(models_path)
    free_disk_outputs = get_free_disk_space_gb(outputs_path)

    mlx_avail = is_mlx_available()
    torch_avail = is_pytorch_available()
    ffmpeg_avail = is_ffmpeg_available()
    python_ver = platform.python_version()

    messages = []
    status = "ready"

    if os_name != "Darwin":
        status = "unsupported"
        messages.append("This application is only supported on macOS.")
    elif not apple_silicon:
        status = "unsupported"
        messages.append("Apple Silicon (M1/M2/M3/M4) is required for optimal performance.")

    if not mlx_avail:
        if status != "unsupported":
            status = "warning"
        messages.append("MLX is not installed. Video generation will not work.")

    if not ffmpeg_avail:
        if status != "unsupported":
            status = "warning"
        messages.append("ffmpeg is missing. Video encoding might fail.")

    if total_mem < settings.min_memory_gb:
        if status != "unsupported":
            status = "warning"
        messages.append(f"This Mac has limited memory ({total_mem}GB). Use distilled or quantised models.")

    if free_disk_models < 10.0: # Arbitrary threshold for warning
        if status != "unsupported":
            status = "warning"
        messages.append(f"Low disk space in models directory ({free_disk_models}GB).")

    return {
        "device": platform.node(),
        "chip": chip,
        "total_memory_gb": total_mem,
        "free_memory_gb": free_mem,
        "os_name": os_name,
        "os_version": os_version,
        "python_version": python_ver,
        "mlx_available": mlx_avail,
        "pytorch_available": torch_avail,
        "ffmpeg_available": ffmpeg_avail,
        "free_disk_models_gb": free_disk_models,
        "free_disk_outputs_gb": free_disk_outputs,
        "status": status,
        "messages": messages
    }
