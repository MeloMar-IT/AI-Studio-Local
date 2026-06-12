# Model Manager

The Model Manager is the central hub for handling local AI models within LTX Studio Local. It abstracts the complexity of model weights and configuration files into user-friendly "Profiles".

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

## Mock vs. Real Status

| Feature | Current Status (v0.1.0) | Planned |
|---------|-------------------------|---------|
| Profile Listing | ✅ Implemented (Mock) | Real model detection |
| Hardware Detection | ✅ Implemented (Mock info) | Real `psutil`/`platform` calls |
| Model Loading | 🔄 Mock stages | Real MLX model loading |
| Model Downloading | ❌ Not implemented | HuggingFace integration |
| Disk Usage Info | ✅ Implemented (Mock) | Real filesystem checks |

## Model Storage

Models are stored in the user's Application Support directory:
`~/Library/Application Support/AI Studio Local/Models/`

The application expects models to follow a specific folder structure if managed manually, but the goal is for the app to handle all model downloads and organization.

## Compatibility

The application is specifically designed for **Apple Silicon**. Intel-based Macs are not supported for generation, although the UI may still function for project management and viewing results.
