# Development Setup

This guide helps you set up LTX Studio Local for local development.

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

The worker handles the AI generation logic.

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
The worker starts a FastAPI server at `http://localhost:8000` by default.

## 3. Set Up the SwiftUI App

1. Open `app/LTXStudioLocal.xcodeproj` in Xcode.
2. Select the `LTXStudioLocal` scheme and a "My Mac" destination.
3. Build and Run (`Cmd + R`).

## 4. Shared Schemas

If you modify the data structures shared between the App and the Worker, update the JSON schemas in `shared/schemas/`.
- Python models in `worker/ltx_worker/schemas/api.py` use these schemas via Pydantic.
- Swift models in `app/LTXStudioLocal/Domain/` must be manually updated to match the schemas.

## 5. Mock Generation Flow

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

## 8. Troubleshooting

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
