ls app# Development Setup

This guide helps you set up AI Studio Local for local development.

## Current Status: MVP Foundation (v0.1.0)

The project has reached the **v0.1.0 MVP Foundation** milestone. All core systems are implemented with mock generation to demonstrate the end-to-end workflow. Real MLX/LTX generation integration is slated for the next phase.

## Prerequisites

- **macOS 14.0 (Sonoma)** or newer.
- **Xcode 15.0** or newer.
- **Python 3.11** or newer.
- **Apple Silicon Mac** (M1, M2, M3, M4) for eventual real generation.

## 1. Clone the Repository

```bash
git clone https://github.com/your-org/ai-studio-local.git
cd ai-studio-local
```

## 2. Set Up the Python Worker

The worker handles the AI generation logic using MLX on Apple Silicon.

```bash
cd worker
python3 -m venv venv
source venv/bin/activate
pip install -e .
```

To run the worker in production mode (default):
```bash
./scripts/run-worker.sh
```

To run the worker in development mode (with auto-reload and mock engine allowed):
```bash
./scripts/run-worker.sh --dev
```

To run the worker with the real MLX/LTX engine explicitly:
```bash
export AI_VIDEO_WORKER_ENGINE_TYPE=ltx
./scripts/run-worker.sh
```
The worker starts a FastAPI server at `http://localhost:8000` by default.

## 3. Set Up the SwiftUI App

1. Open `app/AIStudioLocal.xcodeproj` in Xcode.
2. Select the `AIStudioLocal` scheme and a "My Mac" destination.
3. Build and Run (`Cmd + R`).

The app will attempt to connect to the worker at `http://localhost:8000`. Ensure the worker is started first.

## 4. Model Setup (for Real Generation)

If you are using the real LTX engine (`AI_VIDEO_WORKER_ENGINE_TYPE=ltx`), you need to provide model weights.

1. Create a `models/` directory in the project root.
2. Place your MLX-compatible LTX-Video model files in this directory.
3. The worker expects a folder structure like: `models/ltx-video-0.1-mlx/` containing the `.safetensors` and config files.
4. You can configure the model directory via `AI_VIDEO_WORKER_MODELS_DIR`.

## 5. Shared Schemas

If you modify the data structures shared between the App and the Worker, update the JSON schemas in `shared/schemas/`.
- Python models in `worker/ai_video_worker/schemas/api.py` use these schemas via Pydantic.
- Swift models in `app/AIStudioLocal/Domain/` must be manually updated to match the schemas.

## 5. Environment Modes
The application and worker support three environment modes: `development`, `test`, and `production`.

### Setting Environment Mode
- **Swift App**: Default is `production`. The environment can be overridden by the `LTX_APP_ENVIRONMENT` environment variable or controlled by the `appEnvironment` setting in `UserSettings`.
- **Python Worker**: Default is `production`. Use the `AI_VIDEO_WORKER_ENVIRONMENT` environment variable or the `--dev` flag in `run-worker.sh`.

### Configuring the Application
The application uses standard macOS directories for data storage.

**Swift App Defaults:**
- **App Data/Continuity**: `~/Library/Application Support/AI Studio Local/`
- **Projects**: `~/Documents/AI Studio Local/Projects/`
- **Exports**: `~/Movies/AI Studio Local/Exports/`

These can be customized in the **Settings** panel within the application.

**Python Worker Configuration:**
The worker is configured via environment variables (prefixed with `AI_VIDEO_WORKER_`):
- `AI_VIDEO_WORKER_HOST`: Default `127.0.0.1`
- `AI_VIDEO_WORKER_PORT`: Default `8000`
- `AI_VIDEO_WORKER_LOG_LEVEL`: Default `INFO`
- `AI_VIDEO_WORKER_MODELS_DIR`: Default `models`
- `AI_VIDEO_WORKER_OUTPUT_DIR`: Default `outputs`

### Production Mode Safeguards
Production mode strictly forbids the use of mock engines or mock services. If you try to run in production with a mock engine, the system will fail fast with a clear error.

To run the worker in production mode (requires real MLX/LTX engine):
```bash
export AI_VIDEO_WORKER_ENVIRONMENT=production
export AI_VIDEO_WORKER_ENGINE_TYPE=ltx
./scripts/run-worker.sh
```

## 6. Mock Generation Flow

In the current MVP phase, the worker does not perform real MLX inference. It simulates a generation process:
1. Receives a generation request.
2. Transitions through states: `preparing`, `generating`, `encoding`, `completed`.
3. "Completed" state provides a placeholder result.

This allows for rapid development of the App's UI and interaction logic without needing massive model downloads or high GPU usage during every test.

## 6. Running Tests

### Swift Tests
Run tests within Xcode or via command line:
```bash
cd app
swift test
```

### Python Tests
```bash
cd worker
source venv/bin/activate
pytest
```

## 7. Project Formatting and Linting

We use `swiftlint` for Swift and `ruff` for Python. Use the scripts in `scripts/` to ensure your code follows the project standards:

```bash
./scripts/format.sh
./scripts/lint.sh
```

## 8. No-Mock Production Guard

The project includes a CI guard that prevents production code from importing or using mock/test services. This ensures that mock logic doesn't accidentally leak into production builds.

The guard scans for forbidden names/imports such as `Mock`, `Fake`, `Stub`, `SampleData`, `PreviewFixture`, and `TestAdapter`.

### How to add legitimate test fixtures

If you need to add a test fixture or a mock, follow these rules to avoid violating the production guard:

1. **Use the correct directory**: Place test-only files in a directory named `tests`, `Tests`, or `fixtures`. Files in these directories are automatically ignored by the guard.
2. **SwiftUI Previews**: Use `#if DEBUG` to wrap preview data or mock injections in SwiftUI views. The guard ignores code within `#if DEBUG` blocks.
3. **Internal definitions**: If a class must contain mock data for development purposes (like the current MVP state), ensure the code is wrapped in `#if DEBUG` or the file is specifically excluded in `scripts/check-no-production-mocks.sh`.

Run the guard locally to verify your changes:
```bash
./scripts/check-no-production-mocks.sh
```

## 9. Git Hygiene for Large Files

AI Studio Local deals with large binary files (models, videos, audio). To keep the repository responsive and small, follow these rules:

### Do Not Commit Models
Model files (`.safetensors`, `.ckpt`, `.bin`, `.pt`, `.gguf`) are strictly excluded via `.gitignore`. Store your models in a dedicated `models/` directory outside the repo or in the ignored `models/` folder in the root.

### Generated Media
Generated videos and audio are ignored by default. If you need to share generated results via the repository, use **Git LFS**. A template `.gitattributes` is provided in the root.

### Project Folders
While `.ltxproject` folders are Git-friendly, their internal `generations/`, `assets/`, and `exports/` folders are ignored. This ensures that only the project structure and scene definitions are tracked.

### Summary of Rules
1. **Never** commit model weights.
2. **Avoid** committing generated media unless using LFS.
3. **Keep** local assets outside the repository when possible.
4. **Always** check `git status` before committing to ensure no large binaries are staged.

## 9. Troubleshooting

### Worker connection issues
- Ensure the worker is running (`./scripts/run-worker.sh`).
- Check if `http://localhost:8000/api/v1/health` is accessible in your browser.
- Verify that the App's `GenerationClient` is pointing to the correct URL (default is `http://localhost:8000/api/v1`).

### SwiftUI App build failures
- Ensure you have the latest version of Xcode installed.
- Try cleaning the build folder (`Shift + Cmd + K`).
- Check if `Package.swift` in the `app/` directory has any unresolved dependencies.

### Python environment issues
- If `pip install -e .` fails, ensure you are using a virtual environment and have `pip` updated.
- Some dependencies might require Apple Silicon specific wheels; ensure you are running an ARM64 version of Python.
