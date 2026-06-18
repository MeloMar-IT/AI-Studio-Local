# Release Notes - v0.1.0 (MVP Foundation)

We are excited to announce the first MVP release of **AI Studio Local (AI Studio Local)**! This release establishes the core architectural foundation and user experience for a local-first AI video creation studio on macOS.

## Highlights

- **Native macOS Experience**: A polished SwiftUI application designed specifically for creative workflows on Apple Silicon.
- **Project Studio**: A comprehensive environment for scene-based video creation, featuring a timeline, preview canvas, and deep inspector.
- **Continuity Library**: The core consistency engine. Define Characters, Locations, and Styles once, and reuse them across scenes to maintain a stable visual identity.
- **Prompt Composer**: Intelligent orchestration that combines user intent with library elements and consistency locks to build optimized AI prompts.
- **Decoupled Architecture**: A robust separation between the Swift frontend and a FastAPI-powered Python backend, ensuring a responsive UI even during heavy generation tasks.

## What's Included in v0.1.0

- **Home Dashboard**: Manage your projects and start from templates.
- **Project Persistence**: Transparent `.ltxproject` folder format that is Git-friendly.
- **Scene Management**: Add, duplicate, reorder, and configure scenes with specific generation modes.
- **Render Queue**: Monitor background generation jobs with clear progress states.
- **Model Manager**: View and manage model profiles tailored for different hardware capabilities.
- **Mock Generation Engine**: A fully functional mock generation pipeline to demonstrate end-to-end integration without requiring heavy model downloads.

## Technical Foundation

- **Frontend**: SwiftUI, Swift Concurrency, Combine.
- **Backend**: Python 3.11+, FastAPI, Pydantic, Structured Logging.
- **Contract**: Shared JSON schemas ensuring consistent data flow.

## Note on Real Generation

Version 0.1.0 focuses on the application framework and user experience. While the generation pipeline is fully implemented, it currently uses **mock data**. Real MLX/LTX video generation using local Apple Silicon weights is the primary focus of the upcoming v0.2.0 release.

## Getting Started

1. Ensure you have **macOS 14.0+**, **Xcode 15.0+**, and **Python 3.11+**.
2. Run `./scripts/run-worker.sh` to start the backend.
3. Open `app/AIStudioLocal.xcodeproj` and run the app.

---
*AI Studio Local - Empowering creators with local-first AI.*
