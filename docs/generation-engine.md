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

The engine defines the following generation capabilities. Status reflects the current implementation:

| Capability | Description | Status |
|------------|-------------|--------|
| `text-to-video` | Generate video from text prompts | ✅ Supported (MLX & Mock) |
| `image-to-video` | Generate video from an initial image | ✅ Supported (MLX & Mock) |
| `audio-to-video` | Generate video synchronized with audio | 🔄 API Placeholder |
| `retake` | Regenerate a specific portion of a video | 🔄 API Placeholder |

## Implementation Progress

As of v0.1.0:
- **Mock Engine**: Fully functional for testing the end-to-end UI flow without GPU requirements.
- **MLX Engine**: Implementation is in progress. Basic `text-to-video` and `image-to-video` pipelines are structured but require valid weights and environment setup to execute.

## Configuration

The engine can be configured via environment variables:

- `AI_VIDEO_WORKER_ENGINE_TYPE`: Set to `ltx` for real generation or `mock` for development.
- `AI_VIDEO_WORKER_MIN_MEMORY_GB`: Minimum unified memory required (default: 16GB).

## Job Management and Durability

The `JobStore` and `OutputManager` handle the lifecycle and persistence of generation jobs.

### Durable Metadata

Every generation job is stored on disk in a dedicated directory within the `outputs/` folder. The following information is persisted in `metadata.json`:

- **Identification**: `job_id`, `project_id`, `scene_id`.
- **Status**: Current state (`preparing_prompt`, `generating_video`, `completed`, `failed`, `cancelled`, `interrupted`).
- **Request Details**: Model profile, composed prompt path, and a summary of generation parameters.
- **Timing**: `created_at`, `started_at`, `updated_at`, `completed_at`.
- **Outputs**: Absolute paths to generated video and preview images.
- **Progress History**: A log of progress events with timestamps.

### Recovery and Interruption

The worker is designed to be resilient to restarts:

1. **Recovery**: On startup, the `JobStore` scans the output directory and loads all existing jobs.
2. **Interruption Handling**: Any job found in a non-terminal state (e.g., `generating_video`) during recovery is automatically marked as `interrupted`. This ensures that "ghost" jobs don't stay in the queue and the user receives a clear status.

### Per-Job Logging

In addition to the structured metadata, each job maintains a `job.log` file within its directory. This log captures high-level events, progress updates, and detailed error messages, providing a clear audit trail for debugging and user feedback.

## Error Handling

User-facing errors from the engine are designed to be actionable:

- **Missing MLX**: Prompt the user to install dependencies.
- **Unsupported Mode**: Explain that the feature is planned or not supported by the current model.
- **Insufficient Memory**: Suggest closing other apps or using a smaller model profile.
