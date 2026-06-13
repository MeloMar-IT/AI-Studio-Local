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

### Components

- **GenerationEngine**: The high-level interface used by the worker. It handles hardware validation, metadata preservation, and job workflow.
- **LTXAdapter**: A clean interface that defines the capabilities required for LTX generation (text-to-video, image-to-video, etc.).
- **MLXLTXAdapter**: The primary implementation for macOS (Apple Silicon). It uses MLX to run LTX video models.

## Selected Backend: MLX/LTX

The application uses **MLX** as the primary inference framework. MLX is specifically optimized for Apple Silicon, providing superior performance and memory efficiency compared to generic frameworks.

### Implementation Details

The `MLXLTXAdapter` encapsulates the following:

1. **Dependency Isolation**: MLX and LTX-specific libraries are only imported within the adapter. If they are missing, the adapter produces clear, actionable `DependencyError` messages.
2. **Capability Detection**: The adapter reports which generation modes it supports (e.g., `text-to-video`, `image-to-video`).
3. **Error Handling**: Standardizes errors into `UnsupportedCapabilityError` or `DependencyError` for the UI.

## Capabilities

The engine currently defines the following generation capabilities:

| Capability | Description | Status |
|------------|-------------|--------|
| `text-to-video` | Generate video from text prompts | Supported |
| `image-to-video` | Generate video from an initial image | Supported |
| `audio-to-video` | Generate video synchronized with audio | Planned |
| `retake` | Regenerate a specific portion of a video | Planned |

## Configuration

The engine can be configured via environment variables:

- `LTX_WORKER_ENGINE_TYPE`: Set to `ltx` for real generation or `mock` for development.
- `LTX_WORKER_MIN_MEMORY_GB`: Minimum unified memory required (default: 16GB).

## Error Handling

User-facing errors from the engine are designed to be actionable:

- **Missing MLX**: Prompt the user to install dependencies.
- **Unsupported Mode**: Explain that the feature is planned or not supported by the current model.
- **Insufficient Memory**: Suggest closing other apps or using a smaller model profile.
