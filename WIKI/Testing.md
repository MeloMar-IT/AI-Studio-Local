# Testing Strategy

We maintain high quality standards through automated testing across both our Swift and Python codebases.

## 1. Swift Application Tests

The SwiftUI application uses the **XCTest** framework for unit and integration testing.

### Key Test Areas:
- **Domain Models**: Ensuring `Codable` implementations match the shared schemas.
- **Services**: Verifying business logic in `ProjectStore`, `ContinuityStore`, and `PromptComposer`.
- **ViewModels**: Verifying UI state transitions and user interaction logic.

### Running Tests:
```bash
cd app
swift test
```

## 2. Python Worker Tests

The Python worker uses **pytest** for unit and integration testing.

### Key Test Areas:
- **API Contract**: Verifying that all endpoints follow the API contract and validate requests using Pydantic.
- **Engine Logic**: Testing both `MockLTXAdapter` and `MLXLTXAdapter`.
- **Job Management**: Ensuring `JobStore` correctly handles job persistence, recovery, and state transitions.

### Running Tests:
```bash
cd worker
source venv/bin/activate
pytest
```

## 3. End-to-End Smoke Test

The smoke test verifies that the App and Worker can communicate correctly.

1. **Start Worker**: `./scripts/run-worker.sh`
2. **Start App**: Build and run in Xcode.
3. **Generate**: Create a project and click "Generate" on a scene.
4. **Verify**: Check that progress updates in the UI and a result is produced.

## 4. Production Safeguards

We use a specialized script to ensure that mock services are not accidentally used in production builds.

```bash
./scripts/check-no-production-mocks.sh
```

This script is part of our CI pipeline and prevents "mock leakage" into production releases.
