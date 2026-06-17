# AI Studio Local

AI Studio Local (LTX Studio Local) is a local-first AI video creation studio for macOS. It allows users to generate, edit, retake, extend, and export AI-generated videos using LTX models on Apple Silicon through MLX.

The project prioritizes user experience, local-first privacy, and reusable creative elements.

## Current Status: MVP Foundation (v0.1.0)

The project has reached **v0.1.0 MVP Foundation**. All core UI components, domain models, and service architectures are implemented and verified.

- **SwiftUI App**: Functional shell with Home Dashboard, Project Studio, Continuity Library, Model Manager, and Render Queue.
- **Python Worker**: FastAPI service with mock generation endpoints and job lifecycle management.
- **Generation Flow**: Mock generation is implemented to demonstrate the end-to-end workflow (App -> Worker -> App).
- **Architecture**: Clean separation between Swift frontend and Python backend via shared JSON schemas.

## Project Structure

This is a multi-language repository:

- **app/**: SwiftUI macOS application (Frontend)
- **worker/**: Python MLX/LTX generation service (Backend)
- **shared/**: Shared JSON schemas defining the contract between App and Worker
- **docs/**: Comprehensive project documentation
- **examples/**: Example projects and assets
- **scripts/**: Utility scripts for development, installation, and running services

## Getting Started

### 1. Run the Python Worker

The worker handles the generation requests. For now, it provides mock responses.

```bash
cd worker
python3 -m venv venv
source venv/bin/activate
pip install -e .
python ltx_worker/main.py
```

Or use the provided script:
```bash
./scripts/run-worker.sh
```

### 2. Open the SwiftUI App

Open `app/LTXStudioLocal.xcodeproj` in Xcode and run the application.

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

## TODO: Real Implementation & Mock Removal

The following areas still use mock data or non-functional placeholders and must be replaced with real implementations:

### Python Worker (Backend)
- [ ] **Real MLX/LTX Integration**: Replace dummy MP4 generation in `mlx_adapter.py` with actual MLX-based video generation.
- [ ] **Dependency Enforcement**: Strictly require `mlx` and related libraries in production mode (currently allowed to fail silently in `mlx_adapter.py`).
- [ ] **Generation Engine**: Ensure `LTXGenerationEngine` handles all edge cases (memory, cancellation) using real hardware feedback.
- [ ] **Model Manager**: Enhance model scanning to verify checksums and compatibility beyond folder presence.

### SwiftUI App (Frontend)
- [ ] **Production Services**: Ensure `HTTPGenerationClient` and `RemoteModelStore` are used exclusively in production, with no fallback to mock services.
- [ ] **Hardware Profiler**: Use real hardware data from the worker instead of `MockHardwareProfiler` in all user-facing screens.
- [ ] **Preview Isolation**: Ensure all `static var mock` data in domain models is strictly wrapped in `#if DEBUG`.
- [ ] **Error Handling**: Replace generic "Worker error" messages with actionable guidance based on real worker status (e.g., OOM, missing weights).

### Shared & Infrastructure
- [ ] **Schema Validation**: Implement stricter Pydantic validation for all worker endpoints to ensure API contract integrity.
- [ ] **Metadata Persistence**: Ensure every generation job writes a complete `metadata.json` as per the requirements in `AGENTS.md`.
- [ ] **Automated Tests**: Replace mock-based tests with integration tests that use real (but small/fast) model weights or verifiable stubs.

See [Mock Removal Audit](docs/mock-removal-audit.md) for a detailed technical list of all identified mocks.
