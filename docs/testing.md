# Testing Strategy

This document outlines the testing strategy for LTX Studio Local, covering both the Swift application and the Python worker.

## 1. Swift Application Tests

The SwiftUI application uses the XCTest framework.

### Running Tests

- **In Xcode**: Press `Cmd + U` to run all tests in the active scheme.
- **Via Command Line**:
  ```bash
  cd app
  swift test
  ```

### Key Test Areas

- **Domain Models**: Ensuring `Codable` implementations match the shared schemas.
- **Services**: Mocking network and filesystem calls to test business logic in `ProjectStore`, `ContinuityStore`, and `PromptComposer`.
- **ViewModels**: Verifying UI state transitions and user interaction logic.

## 2. Python Worker Tests

The Python worker uses `pytest` for unit and integration testing.

### Running Tests

```bash
cd worker
source venv/bin/activate
pytest
```

### Key Test Areas

- **API Contract**: Verifying that all endpoints follow the `docs/api-contract.md` and validate requests using Pydantic schemas.
- **Engine Logic**: Testing both `MockLTXAdapter` and `MLXLTXAdapter` (where dependencies allow).
- **Job Management**: Ensuring `JobStore` correctly handles job persistence, recovery, and state transitions.

## 3. End-to-End Smoke Test

The "Smoke Test" verifies that the App and Worker can communicate correctly.

### Smoke Test Checklist

1. **Start Worker**: `./scripts/run-worker.sh` (ensure it starts on port 8000).
2. **Start App**: Build and run the `LTXStudioLocal` scheme in Xcode.
3. **Health Check**:
   - Verify that the app shows "Worker Connected" (or similar status).
   - Check `http://localhost:8000/api/v1/health` in a browser.
4. **Create Project**: Create a new project in the App.
5. **Add Scene**: Add a scene and enter a simple prompt.
6. **Generate (Mock)**: Click **Generate**.
   - Verify the progress bar appears in the App.
   - Verify the Worker logs show a new job being created.
   - Verify the job completes and a placeholder video appears in the App.
7. **Continuity**: Attach a continuity element to a scene and verify the composed prompt includes its content.

## 4. No-Mock Production Guard

A specialized script ensures that mock services are not accidentally used in production builds.

```bash
./scripts/check-no-production-mocks.sh
```

This script is part of the CI pipeline and should be run locally before any major merge.

## 5. Manual Real-Model Testing

For verifying actual MLX generation, refer to the [Manual Real-Model Test Checklist](manual-real-model-test-checklist.md).
