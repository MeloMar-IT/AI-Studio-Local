# Generation Engine

The Generation Engine is responsible for executing AI video generation jobs. It abstracts the underlying MLX/LTX implementation from the rest of the worker and the SwiftUI application.

## Architecture

The engine follows an adapter pattern to ensure that the API and job management logic remain decoupled from specific machine learning libraries.

```text
Worker API / JobStore
        │
        ▼
LTXGenerationEngine (Engine Interface)
        │
        ▼
   LTXAdapter (Adapter Interface)
        │
        ├── MLXLTXAdapter (Real MLX implementation)
        └── MockLTXAdapter (Optional mock for testing)
```

## Selected Backend: MLX/LTX

The application uses **MLX** as the primary inference framework. MLX is specifically optimized for Apple Silicon, providing superior performance and memory efficiency compared to generic frameworks like PyTorch.

### Key Benefits of MLX:
- **Unified Memory**: Direct access to shared CPU/GPU memory on M1/M2/M3 chips.
- **Performance**: High-speed inference specifically tuned for macOS.
- **Native Experience**: No need for complex Docker setups or heavy Linux environments.

## Capabilities

The engine defines the following generation capabilities:

| Capability | Description | Status |
|------------|-------------|--------|
| `text-to-video` | Generate video from text prompts | ✅ Supported |
| `image-to-video` | Generate video from an initial image | ✅ Supported |
| `audio-to-video` | Generate video synchronized with audio | 🔄 Planned |
| `retake` | Regenerate a specific portion of a video | 🔄 Planned |

## Metadata & Reproducibility

Every generation job is stored on disk with full metadata in a `metadata.json` file. This includes:
- **Identification**: IDs for job, project, and scene.
- **Parameters**: Model profile, prompt, seed, steps, and resolution.
- **Timestamps**: Full lifecycle timing (created, started, finished).
- **Environment**: App and worker version tracking.

## Resilience

The worker is designed to be resilient to interruptions:
- **State Recovery**: On startup, the worker scans for existing jobs and restores their state.
- **Interruption Detection**: Jobs that were in progress when the worker was closed are automatically marked as `interrupted`.
- **Per-Job Logs**: Each generation has its own log file for easier troubleshooting.

## Error Handling

User-facing errors are designed to be actionable:
- **Memory Errors**: Suggests lowering resolution or closing other apps.
- **Dependency Issues**: Guides the user on how to repair the Python environment.
- **Hardware Warnings**: Alerts if the current Mac doesn't meet the minimum requirements for a specific model profile.
