# AI Studio Local

AI Studio Local (AI Studio Local) is a local-first AI video creation studio for macOS. It allows users to generate, edit, retake, extend, and export AI-generated videos using LTX models on Apple Silicon through MLX.

The project prioritizes user experience, local-first privacy, and reusable creative elements.

## Current Status: Real Generation Integrated (v0.2.0)

The project has transitioned from an MVP Foundation to a **functional generation studio**. All core mocks in the generation path have been removed.

- **SwiftUI App**: Functional shell with Home Dashboard, Project Studio, Continuity Library, Model Manager, and Render Queue.
- **Python Worker**: FastAPI service with **Real MLX/LTX video generation**. No more mock placeholders or ffmpeg-generated videos.
- **Generation Flow**: End-to-end real generation workflow (App -> Worker -> MLX -> App).
- **Architecture**: Clean separation between Swift frontend and Python backend via shared JSON schemas, with strict isolation of debug mocks.

## Project Structure

This is a multi-language repository:

- **app/**: SwiftUI macOS application (Frontend)
- **worker/**: Python MLX/LTX generation service (Backend)
- **shared/**: Shared JSON schemas defining the contract between App and Worker
- **docs/**: Comprehensive project documentation
- **examples/**: Example projects and assets
- **scripts/**: Utility scripts for development, installation, and running services

## Getting Started

### Quick Start (Recommended)

The easiest way to get everything running is using the `Makefile`:

1.  **Install dependencies**:
    ```bash
    make install
    ```

2.  **Start the Python Worker**:
    ```bash
    make run-worker
    ```
    *In another terminal tab:*
    ```bash
    make run-worker-dev  # For development mode with auto-reload and mock support
    ```

3.  **Start the SwiftUI App**:
    ```bash
    make run-app
    ```
    *Or open `app/AIStudioLocal.xcodeproj` in Xcode and run the application (Cmd+R).*

### Manual Startup

If you prefer to run components manually:

#### 1. Python Worker

The worker handles the generation requests.

```bash
cd worker
python3 -m venv venv
source venv/bin/activate
pip install -e .
python3 ai_video_worker/main.py
```

Or use the provided script:
```bash
./scripts/run-worker.sh [--dev]
```

#### 2. SwiftUI App

```bash
cd app
swift run AIStudioLocal
```

Or open `app/AIStudioLocal.xcodeproj` in Xcode.

## Core Concepts

### Git Hygiene & Large Files

This project is designed to be Git-friendly. However, AI models and generated media are large and should generally **not** be committed to the repository.

1. **Do not commit models**: Model weights (`.safetensors`, `.ckpt`, etc.) are ignored by default.
2. **Do not commit generated media**: Videos and audio are ignored. Only commit them if you intentionally use Git LFS.
3. **Keep project metadata Git-friendly**: Project files (`.json`, `.md`) are small and structured for clean diffs.
4. **Store large assets externally**: Keep large local datasets or reference assets outside the repository when possible.

### Continuity Library
Reusable creative blocks (Characters, Locations, Styles) that can be attached to scenes to maintain visual consistency across a project.

### Project Format
Projects are stored as `.ltxproject` folders containing structured JSON files and assets, making them Git-friendly.

### Prompt Composer
A service that automatically combines scene prompts with attached continuity elements and consistency locks before sending them to the worker.

## Documentation

- **[User Guide (Start Here)](docs/user-guide.md)**: How to set up and run the application.
- **[Model Download Guide](docs/model-download-guide.md)**: Where to get the AI models.
- [Architecture Overview](docs/architecture.md)
- [User Experience](docs/user-experience.md)
- [Development Setup](docs/development-setup.md)
- [Testing Strategy](docs/testing.md)
- [Continuity Library](docs/continuity-library.md)
- [Project Format](docs/project-format.md)
- [Model Manager](docs/model-manager.md)
- [Generation Engine](docs/generation-engine.md)
- [API Contract](docs/api-contract.md)
- [Manual Real-Model Test Checklist](docs/manual-real-model-test-checklist.md)
- [Release Candidate Checklist](docs/release-candidate-checklist.md)

## Goals
- Native macOS experience.
- Local-first privacy and performance.
- Reusable creative elements through a Continuity Library.
- High-quality AI video generation using MLX on Apple Silicon.

## DONE: Real Implementation & Mock Removal

The following areas have been replaced with real implementations:

### Python Worker (Backend)
- [x] **Real MLX/LTX Integration**: Replaced dummy MP4 generation in `mlx_adapter.py` with actual MLX-based video generation.
- [x] **Dependency Enforcement**: Strictly require `mlx` and `ltx-video` libraries.
- [x] **Generation Engine**: `LTXGenerationEngine` handles real generation and fails loudly if requirements are not met.

### SwiftUI App (Frontend)
- [x] **Production Services**: `HTTPGenerationClient` and `RemoteModelStore` are used for fetching data.
- [x] **Mock Removal**: Removed fallbacks to `ModelProfile.mocks` in production view models.
- [x] **Preview Isolation**: All `static var mock` data in domain models is strictly wrapped in `#if DEBUG`.

See [Mock Removal Audit](docs/mock-removal-audit.md) for the completion summary.
