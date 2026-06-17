# Model Manager

The Model Manager is the central hub for handling local AI models within AI Studio Local. It abstracts the complexity of model weights and configuration files into user-friendly "Profiles".

## Model Profiles

Instead of interacting directly with `.safetensors` or `.pth` files, users select from pre-defined profiles:

- **Fast Draft**: Optimized for speed. Low resolution, fewer steps. Ideal for testing compositions.
- **Balanced**: The default profile for most creative work. Good balance of quality and speed.
- **Production Quality**: High resolution, maximum detail, slower generation.
- **Memory Optimized**: For Macs with limited Unified Memory (e.g., 8GB or 16GB models).

## Hardware Profiling

The Model Manager integrates with the **Hardware Profiler** to recommend the best profile for your specific Mac. It detects:
- Apple Silicon Chip (M1, M2, M3, M4 and their variants).
- Total Unified Memory.
- Available Disk Space.

## Model Storage

The application uses standard macOS directories for model storage.

**Default Path:**
`~/Library/Application Support/AI Studio Local/Models/`

The Python worker can be configured to point to any directory using the `LTX_WORKER_MODELS_DIR` environment variable.

## Hardware Requirements

AI Studio Local is specifically designed for **Apple Silicon**.
- **Minimum**: 16GB Unified Memory (8GB may work with Memory Optimized profiles).
- **Recommended**: 32GB+ Unified Memory for high-resolution production.
- **Disk**: 10GB+ free space for models and project assets.

Intel-based Macs are not supported for local video generation.
