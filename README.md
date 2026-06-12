# AI Studio Local

AI Studio Local (LTX Studio Local) is a local-first AI video creation studio for macOS. It allows users to generate, edit, retake, extend, and export AI-generated videos using LTX models on Apple Silicon through MLX.

The project prioritizes user experience, local-first privacy, and reusable creative elements.

## Current Status: MVP Foundation (v0.1.0-pre)

The project is currently in the **MVP Foundation** phase. All core UI components, domain models, and service architectures are implemented.

- **SwiftUI App**: Fully functional shell with Home Dashboard, Project Studio, Continuity Library, Model Manager, and Render Queue.
- **Python Worker**: FastAPI-based skeleton with mock generation endpoints.
- **Generation Flow**: Mock generation is implemented to demonstrate the end-to-end workflow (App -> Worker -> App).
- **MLX/LTX Integration**: Planned for the next phases. Real local generation is not yet enabled.

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
- [Continuity Library](docs/continuity-library.md)
- [Project Format](docs/project-format.md)
- [Model Manager](docs/model-manager.md)

## Goals

- Native macOS experience.
- Local-first privacy and performance.
- Reusable creative elements through a Continuity Library.
- High-quality AI video generation using MLX on Apple Silicon.
