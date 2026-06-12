# Architecture Overview

LTX Studio Local uses a two-part architecture consisting of a native macOS SwiftUI application and a local Python-based generation worker.

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
        └── HardwareProfiler (System info)
        │
        ▼
Local Python Worker (FastAPI)
        │
        ├── Job Queue (Async execution)
        ├── Job Store (State persistence)
        ├── MLX Runtime (Planned)
        ├── LTX Pipeline (Planned)
        └── Media Encoder (Mock)
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

### 3. Local Python Worker (`worker/`)
A background service that executes the computationally intensive generation tasks.
- **FastAPI**: Provides a REST API for the App to submit jobs and check status.
- **Job Store**: A simple in-memory (for now) store to track the status of background jobs.
- **MLX/LTX Engine**: (Planned) The integration with MLX to run LTX video models on Apple Silicon.

### 4. Shared Schemas (`shared/schemas/`)
To ensure the App and Worker speak the same language, we use shared JSON schemas. These schemas are used to generate Pydantic models in Python and are manually mirrored in Swift `Codable` models.

## Communication Flow

1. **User Action**: User clicks "Generate" in the Project Studio.
2. **Prompt Composition**: `PromptComposer` builds the final prompt.
3. **Request**: `GenerationClient` sends a POST request to `/generate/text-to-video`.
4. **Queue**: Worker receives the request, creates a job ID, and returns it immediately.
5. **Background Work**: Worker begins the mock generation process, updating its job status over time.
6. **Polling**: App polls `/jobs/{id}` to update the progress bar in the Render Queue.
7. **Completion**: Once finished, the worker saves the output file, and the app reflects the completed state.

## Local-First Principle
- All project data is stored in user-accessible folders.
- All generation happens on the local machine (no cloud dependency).
- Privacy is guaranteed by never sending prompts or media to external servers.
