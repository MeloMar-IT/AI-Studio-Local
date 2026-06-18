# Architecture Overview

AI Studio Local uses a two-part architecture consisting of a native macOS SwiftUI application and a local Python-based generation worker.

## High-Level Architecture

```text
SwiftUI macOS App (Swift)
        │
        ▼
Application Services
        │
        ├── ProjectStore (File persistence)
        ├── ContinuityStore (Reusable elements)
        ├── ModelStore (Model profiles)
        ├── GenerationClient (Worker API communication)
        ├── ExportService (Mock)
        ├── HardwareProfiler (System info)
        ├── FileSystemService (Directory management)
        └── UserSettings (App configuration)
        │
        ▼
Local Python Worker (FastAPI)
        │
        ├── Job Queue (Async execution)
        ├── Job Store (State persistence)
        ├── MLX Runtime (In progress)
        ├── LTX Pipeline (In progress)
        └── Media Encoder (FFmpeg)
```

## Component Descriptions

### 1. SwiftUI macOS App (`app/`)
The frontend responsible for the user experience. It follows a clean architecture with:
- **Views**: Small, composable SwiftUI views.
- **ViewModels**: State management and business logic for views.
- **Services**: Abstracted logic for persistence, networking, and hardware interaction.
- **Domain**: Pure data models using `Codable` for JSON serialization.

### 2. Application Services
- **ProjectStore**: Manages the loading and saving of `.ltxproject` folders.
- **ContinuityStore**: Manages the library of reusable characters, locations, and styles.
- **GenerationClient**: Handles communication with the Python worker via REST API.
- **PromptComposer**: Composes the final prompt by combining scene-specific text with attached continuity elements.
- **FileSystemService**: Provides robust directory management, ensuring standard macOS paths are used and validated.
- **UserSettings**: Manages application-wide settings, persisting them via `@AppStorage` and aligning with macOS Application Support standards.

### 3. Local Python Worker (`worker/`)
A background service that executes the computationally intensive generation tasks.
- **FastAPI**: Provides a REST API for the App to submit jobs and check status.
- **Job Store**: Manages persistence and recovery of background jobs across restarts.
- **MLX/LTX Engine**: The integration with MLX to run LTX video models on Apple Silicon. Supports both real generation and mock mode for development.

### 4. Shared Schemas (`shared/schemas/`)
To ensure the App and Worker speak the same language, we use shared JSON schemas. These schemas are used to generate Pydantic models in Python and are manually mirrored in Swift `Codable` models.

## Communication Flow

1. **User Action**: User clicks "Generate" in the Project Studio.
2. **Prompt Composition**: `PromptComposer` builds the final prompt.
3. **Request**: `GenerationClient` sends a POST request to `/generate/text-to-video` or `/generate/retake`.
4. **Queue**: Worker receives the request, creates a job ID, and returns it immediately.
5. **Background Work**: Worker begins the generation process (mocked or real), updating its job status over time.
6. **Polling**: App polls `/jobs/{id}` to update the progress bar in the Render Queue.
7. **Completion**: Once finished, the worker saves the output file, and the app reflects the completed state.

## Local-First Principle
- All project data is stored in user-accessible folders.
- All generation happens on the local machine (no cloud dependency).
- Privacy is guaranteed by never sending prompts or media to external servers.

## Environment Modes & Mock Boundaries

The application and worker support three environment modes:

- **development**: Allows the use of mock engines, mock services, and preview fixtures. Default mode for local development.
- **test**: Used for automated testing. Allows mocks and test fixtures.
- **production**: Strict mode for real users.

### Boundary Enforcement

To prevent accidental use of mocks in production:
1. **Swift App**: `AppState` init will `fatalError` if a mock service is injected while `appEnvironment` is set to `.production`.
2. **Python Worker**: The worker will raise a `RuntimeError` during startup if `engine_type` is set to `mock` while `environment` is `production`.
