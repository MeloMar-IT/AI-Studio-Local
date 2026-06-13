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

| Feature | Current Status (v0.1.0) | Implementation |
|---------|-------------------------|----------------|
| Profile Listing | ✅ Functional | `ModelStore` (Swift) & `/models` (Python) |
| Hardware Detection | ✅ Functional | `HardwareProfiler` (Swift) & `/hardware` (Python) |
| Model Loading | 🔄 In Progress | `MLXLTXAdapter` (Python) |
| Model Downloading | ❌ Not implemented | Planned for v0.2.0 |
| Disk Usage Info | ✅ Functional | `FileSystemService` |

## Model Storage

The application uses standard macOS directories for model storage.

**Default Path:**
`~/Library/Application Support/LTX Studio Local/Models/`

The Python worker can be configured to point to any directory using the `LTX_WORKER_MODELS_DIR` environment variable. By default, it looks for a `models/` directory in its current working directory.

### Manual Model Import

To manually add a model for the real MLX engine:
1. Download the MLX-compatible LTX-Video weights.
2. Create a folder named after the model version (e.g., `ltx-video-v0.1-mlx`) in the `models/` directory.
3. Place the `.safetensors` files, `config.json`, and any required tokenizer files inside that folder.
4. Restart the worker. The model should now be listed in the **Model Manager** if the ID matches a known profile.

## Compatibility

The application is specifically designed for **Apple Silicon**. Intel-based Macs are not supported for generation, although the UI may still function for project management and viewing results.
