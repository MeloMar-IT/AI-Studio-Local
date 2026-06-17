# Development Setup

This guide helps you set up AI Studio Local for local development.

## Prerequisites

- **macOS 14.0 (Sonoma)** or newer.
- **Xcode 15.0** or newer.
- **Python 3.11** or newer.
- **Apple Silicon Mac** (M1, M2, M3, M4) for local generation.

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

To run the worker:
```bash
./scripts/run-worker.sh
```

To run in development mode (with auto-reload and mock engines allowed):
```bash
./scripts/run-worker.sh --dev
```

## 3. Set Up the SwiftUI App

1. Open `app/LTXStudioLocal.xcodeproj` in Xcode.
2. Select the `LTXStudioLocal` scheme and a "My Mac" destination.
3. Build and Run (`Cmd + R`).

The app will attempt to connect to the worker at `http://localhost:8000`. Ensure the worker is started first.

## 4. Environment Modes

The system supports three environment modes:
- **development**: Allows mocks and preview fixtures. Default for local development.
- **test**: Used for automated testing.
- **production**: Strict mode. Forbids mocks and requires real MLX hardware.

## 5. Configuration

### Swift App
Settings are managed in the **Settings** panel within the app, covering project storage paths and UI preferences.

### Python Worker
Configured via environment variables (prefixed with `LTX_WORKER_`):
- `LTX_WORKER_HOST`: Default `127.0.0.1`
- `LTX_WORKER_PORT`: Default `8000`
- `LTX_WORKER_MODELS_DIR`: Where to look for models.
- `LTX_WORKER_ENGINE_TYPE`: `ltx` (real) or `mock`.

## 6. Project Formatting and Linting

We maintain high code quality standards. Run these before submitting changes:

```bash
./scripts/format.sh
./scripts/lint.sh
```

## 7. Troubleshooting

- **Connection**: Verify `http://localhost:8000/health` in your browser.
- **Xcode**: Clean build folder (`Shift + Cmd + K`) if you see strange compilation errors.
- **Python**: Ensure you are using ARM64 Python for MLX compatibility.
