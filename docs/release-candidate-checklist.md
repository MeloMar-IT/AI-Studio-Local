# Release Candidate Checklist

This checklist is used to verify a release candidate for LTX Studio Local. It must be executed on an Apple Silicon Mac.

## 1. Clean Environment Setup

- [ ] **Clean Clone**: Clone the repository into a fresh directory.
  ```bash
  git clone https://github.com/your-org/ai-studio-local.git ltx-rc-test
  cd ltx-rc-test
  ```
- [ ] **Worker Dependencies**: Install Python dependencies.
  ```bash
  cd worker
  python3 -m venv venv
  source venv/bin/activate
  pip install -e .
  cd ..
  ```
- [ ] **App Dependencies**: Ensure Swift packages are resolved.
  ```bash
  cd app
  xcodebuild -resolvePackageDependencies
  cd ..
  ```

## 2. Configuration & Model Validation

- [ ] **Model Directory**: Create and configure the models directory.
  ```bash
  mkdir -p models
  # Place real models in the directory if available
  export LTX_WORKER_MODELS_DIR=$(pwd)/models
  ```
- [ ] **Worker Startup**: Start the worker with the real engine (or mock for MVP validation).
  ```bash
  # For real model validation:
  export LTX_WORKER_ENGINE_TYPE=ltx
  ./scripts/run-worker.sh
  ```
- [ ] **Health Check**: Verify worker is responding.
  ```bash
  curl http://localhost:8000/api/v1/health
  ```
- [ ] **Model Validation**: Verify worker can see available models.
  ```bash
  curl http://localhost:8000/api/v1/models
  ```

## 3. Application Verification

- [ ] **App Startup**: Launch the SwiftUI app from Xcode.
  - Open `app/LTXStudioLocal.xcodeproj`.
  - Build and Run (`Cmd + R`).
  - Verify app connects to the worker (Status indicator should be green/active).
- [ ] **Project Management**:
  - [ ] Create a new project.
  - [ ] Save the project and verify `.ltxproject` folder structure.
- [ ] **Continuity Library**:
  - [ ] Create a new Character element.
  - [ ] Create a new Location element.
  - [ ] Create a new Style element.
  - [ ] Attach elements to a scene.
- [ ] **Prompt Composition**:
  - [ ] Use the "View Composed Prompt" action in the Scene Inspector.
  - [ ] Verify that Character, Location, and Style prompts are correctly merged.

## 4. Generation & Output Verification

- [ ] **Text-to-Video Generation**:
  - [ ] Trigger a generation from a scene.
  - [ ] Verify progress stages (preparing, loading_model, generating, etc.).
  - [ ] Verify successful completion.
- [ ] **Image-to-Video Generation** (if supported/implemented):
  - [ ] Upload an image to a scene and trigger generation.
- [ ] **Metadata Verification**:
  - [ ] Open the scene's `generations/gen-XXX/metadata.json`.
  - [ ] Verify all required fields (prompt, model, seed, steps, etc.) are present.
- [ ] **Timeline & Export**:
  - [ ] Arrange multiple scenes in the timeline.
  - [ ] Export the timeline to MP4.
  - [ ] Verify the exported MP4 plays correctly and contains all scenes.

## 5. Quality & Compliance

- [ ] **Run All Tests**: Ensure all automated tests pass.
  ```bash
  ./scripts/test.sh
  ```
- [ ] **No-Mock Production Guard**: Verify no production code leaks mocks.
  ```bash
  ./scripts/check-no-production-mocks.sh
  ```
- [ ] **Linting**: Verify code style compliance.
  ```bash
  ./scripts/lint.sh
  ```
- [ ] **CI Passing**: Verify that the latest GitHub Actions runs for the branch are green.
- [ ] **Git Cleanliness**:
  - [ ] Verify `.gitignore` correctly excludes `models/`, `venv/`, and generated media.
  - [ ] Run `git status` to ensure no large binaries or local configs are staged.

## 6. Definition of Done

- [ ] App remains responsive during generation.
- [ ] Errors are actionable and user-friendly.
- [ ] No hard-coded absolute paths.
- [ ] Metadata is written for every generation.
- [ ] All features have corresponding tests.
