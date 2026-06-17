# AI Studio Local — Real Implementation TODO for Junie

This file is the second-stage TODO list for **AI Studio Local**.

The first project structure and mock application have already been implemented. This TODO list is for turning the application into a working product by removing mocks, replacing them with real code, and adding tests that prove every part works.

The goal is not to make a pretty demo. The goal is to make a maintainable Git project with a real SwiftUI macOS application, a real Python MLX/LTX worker, real persistence, real project files, real model management, real generation jobs, real media outputs, and automated tests.

---

## Ground rules for Junie

Before starting any task, Junie must read:

```text
AGENTS.md
README.md
ROADMAP.md
docs/architecture.md
docs/development-setup.md
docs/user-experience.md
docs/continuity-library.md
```

Junie must follow these rules:

1. Do not remove the existing UX structure.
2. Do not replace the SwiftUI app with a web UI.
3. Do not turn the project into a Java/Kotlin IntelliJ application.
4. Do not hard-code user-specific absolute paths.
5. Do not keep fake data once a real implementation exists.
6. Do not silently fall back to mocks.
7. Every removed mock must be replaced by working code or a clearly failing placeholder with a useful error.
8. Every feature must have tests.
9. Every worker endpoint must have schema validation.
10. Every generation job must write metadata.
11. The UI must remain responsive during long-running jobs.
12. All errors must be actionable and user-friendly.
13. Every task must be committed separately with a meaningful commit message.

---

## Definition of done for this phase

This phase is complete only when:

```text
- The Python worker starts locally.
- The SwiftUI app can connect to the worker.
- Mock model data has been replaced by real model discovery/configuration.
- Mock generation jobs have been replaced by real job execution plumbing.
- Text-to-video has a real implementation path using MLX/LTX or a clearly isolated adapter ready for the selected MLX/LTX package.
- Image-to-video has a real implementation path or a failing explicit unsupported error.
- Audio-to-video and retake are no longer fake; they either work or return honest capability errors.
- Projects are saved and loaded from real project folders.
- Continuity Library data is persisted in real JSON files.
- Prompt Composer is tested.
- Generation jobs are persisted with metadata.
- The app can display generated output files.
- The export pipeline can combine generated clips into an MP4.
- Unit tests, API tests, integration tests, and smoke tests exist.
- CI runs linting and tests.
- No mock generation path is reachable from production mode.
```

---

# Phase 0 — Audit the current implementation

## 0.1 Inspect current repository state

### TODO

- [ ] Open the existing repository.
- [ ] Identify every mock, fake, stub, placeholder, TODO, FIXME, and hard-coded sample.
- [ ] Create a file `docs/mock-removal-audit.md`.
- [ ] List every mock by file path, type, owner feature, and required replacement.
- [ ] Classify each item as:
  - `remove-now`
  - `replace-with-real-code`
  - `keep-as-preview-only`
  - `convert-to-test-fixture`
  - `explicitly-unsupported`

### Junie prompt

```text
Read the current AI Studio Local repository and create a complete mock-removal audit.

Search for all mocks, fake data, sample-only services, placeholders, TODOs, FIXMEs, hard-coded responses, fake worker endpoints, mock model profiles, fake generation jobs, fake project data, and any preview-only data that may accidentally be used in production.

Create docs/mock-removal-audit.md with a table containing:

- file path
- symbol/class/function name
- feature area
- current mock behaviour
- required real replacement
- classification: remove-now, replace-with-real-code, keep-as-preview-only, convert-to-test-fixture, explicitly-unsupported
- risk if left unchanged

Do not change code yet. Only produce the audit document.
```

### Tests to prove it

- [ ] Run a repository-wide search for `mock`, `fake`, `sample`, `stub`, `TODO`, `FIXME`, `placeholder`.
- [ ] Confirm every result is listed in `docs/mock-removal-audit.md` or justified as harmless.

---

## 0.2 Add production/mock boundary rules

### TODO

- [ ] Add a clear environment mode: `development`, `test`, `production`.
- [ ] Ensure mocks can only run in development previews or tests.
- [ ] Production mode must fail if a mock service is injected.
- [ ] Add unit tests proving mock services cannot be used in production.

### Junie prompt

```text
Implement strict production/mock boundary rules.

Add an environment mode concept to the SwiftUI app and Python worker:

- development
- test
- production

Mocks, fake data, sample jobs, fake model lists, and fake generation outputs must only be allowed in development previews or tests. Production mode must fail fast with a clear error if any mock service is injected or any fake endpoint is used.

Add tests proving:

1. Production mode rejects mock services.
2. Development mode can still use preview fixtures.
3. Test mode can use test fixtures.
4. No production service imports preview-only data.

Update documentation to explain the boundary.
```

### Tests to prove it

- [ ] Swift unit test: production DI container rejects mock services.
- [ ] Python unit test: worker production config rejects fake generation engine.
- [ ] CI fails if production code imports preview fixture modules.

---

# Phase 1 — Real configuration system

## 1.1 Implement real app configuration

### TODO

- [ ] Add a real configuration file location for the app.
- [ ] Support user-level config.
- [ ] Support project-level config.
- [ ] Support worker URL configuration.
- [ ] Support model directory configuration.
- [ ] Support output directory configuration.
- [ ] Add validation and defaults.

### Suggested config locations

```text
~/Library/Application Support/AI Studio Local/config.json
~/Library/Application Support/AI Studio Local/continuity-library/
~/Library/Application Support/AI Studio Local/models/
~/Movies/AI Studio Local/Exports/
```

### Junie prompt

```text
Replace hard-coded configuration values with a real configuration system.

Implement app configuration for the SwiftUI application and worker configuration for the Python service.

The configuration must support:

- app data directory
- global continuity library directory
- model directory
- default project directory
- export directory
- local worker URL
- environment mode
- logging level
- default generation profile

Use sensible macOS defaults under ~/Library/Application Support/AI Studio Local where appropriate.

Add validation so missing or invalid config values produce clear actionable errors.

Add unit tests for:

- default config creation
- config loading
- config validation
- invalid config handling
- environment-specific config
```

### Tests to prove it

- [ ] Swift config tests pass.
- [ ] Python config tests pass.
- [ ] App starts with no config and creates defaults.
- [ ] Invalid config produces actionable error.

---

# Phase 2 — Real project persistence

## 2.1 Replace sample project storage with real folder-based project storage

### TODO

- [ ] Implement `.ltxproject` folder creation.
- [ ] Save `project.json`.
- [ ] Save `timeline.json`.
- [ ] Save scene folders.
- [ ] Save scene prompt files.
- [ ] Save generation metadata.
- [ ] Save asset references.
- [ ] Load projects from disk.
- [ ] Validate project structure.
- [ ] Add project migration version field.

### Junie prompt

```text
Replace sample project storage with real folder-based project persistence.

Implement a project format where each project is a folder ending with .ltxproject.

Required structure:

ProjectName.ltxproject/
  project.json
  timeline.json
  scenes/
    scene-001/
      scene.json
      prompt.md
      generations/
      references/
  assets/
    images/
    audio/
    video/
    overlays/
  exports/
  README.md

Implement:

- create project
- open project
- save project
- save scene
- load scene
- validate project folder
- detect corrupt project
- project schema version
- project migration placeholder

Remove any production usage of sample project data.

Add tests with temporary directories proving projects can be created, saved, loaded, modified, and validated.
```

### Tests to prove it

- [ ] Create project test.
- [ ] Save/load project test.
- [ ] Add scene and reload test.
- [ ] Corrupt project validation test.
- [ ] Schema version test.
- [ ] No sample project used outside previews.

---

## 2.2 Add Git-friendly project behaviour

### TODO

- [x] Generate project README.
- [x] Generate project `.gitignore`.
- [x] Generate optional `.gitattributes` for Git LFS.
- [x] Store metadata as readable JSON.
- [x] Store prompts as Markdown.

### Junie prompt

```text
Make the .ltxproject project format Git-friendly.

When a new project is created, generate:

- README.md explaining the project
- .gitignore for generated media, cache files, large models and temporary files
- optional .gitattributes recommending Git LFS for video/audio/image assets

Ensure prompt files are stored as Markdown and metadata is stored as readable pretty-printed JSON.

Add tests proving:

- .gitignore is created
- README.md is created
- JSON is pretty printed
- prompt.md is written and loaded correctly
```

### Tests to prove it

- [x] Project README generation test.
- [x] Project `.gitignore` generation test.
- [x] Prompt Markdown save/load test.

---

# Phase 3 — Real Continuity Library persistence

## 3.1 Replace in-memory continuity data with real JSON storage

### TODO

- [ ] Store global continuity elements in app support directory.
- [ ] Store one JSON file per element.
- [ ] Add category folders.
- [ ] Implement create/edit/delete/search.
- [ ] Implement import/export continuity library.
- [ ] Validate element schema.
- [ ] Preserve references to assets.

### Junie prompt

```text
Replace all in-memory or sample-only Continuity Library data with real JSON-backed persistence.

Create a global continuity library under:

~/Library/Application Support/AI Studio Local/continuity-library/

Use category folders:

characters/
locations/
styles/
camera-presets/
audio-identities/
brand-kits/
prompt-blocks/
loras/
export-templates/

Store one readable JSON file per element.

Implement:

- create element
- edit element
- delete element
- list by type
- search by name, description and tags
- import library from folder
- export library to folder
- validate element schema
- handle missing referenced assets gracefully

Add tests using temporary folders.
```

### Tests to prove it

- [ ] Create character element test.
- [ ] Create location element test.
- [ ] Search by tag test.
- [ ] Import/export library test.
- [ ] Invalid element schema test.
- [ ] Missing asset warning test.

---
=====================================
## 3.2 Attach real continuity elements to scenes

### TODO

- [ ] Attach elements by stable ID.
- [ ] Resolve elements when project opens.
- [ ] Warn when referenced element is missing.
- [ ] Allow replacing missing element.
- [ ] Add consistency locks persistence.

### Junie prompt

```text
Implement real scene-to-continuity-element references.

Scenes must store references to continuity elements by stable ID, not by copying full objects into the scene.

When a project opens, resolve all scene element references against the global Continuity Library.

If an element is missing, show a non-blocking warning in the UI and allow the user to remove or replace the missing reference.

Persist consistency locks in scene.json:

- character_identity
- location
- style
- brand
- audio_identity
- seed

Add tests proving references survive save/load and missing references are handled cleanly.
```

### Tests to prove it

- [ ] Scene references continuity element by ID.
- [ ] Scene reload resolves element.
- [ ] Missing element produces warning, not crash.
- [ ] Consistency locks persist.

---

# Phase 4 — Prompt Composer production implementation

## 4.1 Implement deterministic Prompt Composer

### TODO

- [ ] Compose prompt from scene + elements.
- [ ] Compose negative prompt.
- [ ] Include camera and audio prompt blocks.
- [ ] Respect ordering.
- [ ] Deduplicate repeated prompt text.
- [ ] Save composed prompt per generation.

### Junie prompt

```text
Implement the production PromptComposer service.

The PromptComposer must take:

- scene prompt
- scene negative prompt
- attached character elements
- attached location elements
- attached visual styles
- attached camera presets
- attached audio identities
- attached brand prompt rules
- attached prompt blocks
- consistency locks

It must produce:

- composed positive prompt
- composed negative prompt
- a list of source elements used
- warnings for missing or invalid elements

Rules:

1. Scene prompt must come first.
2. Character identity text must be included before style text.
3. Location text must be included before camera text.
4. Audio cues must be included near the end.
5. Negative prompts must be deduplicated.
6. Empty prompt blocks must be ignored.
7. The result must be deterministic for the same input.

Save the composed prompt and prompt metadata with every generation.

Add comprehensive unit tests.
```

### Tests to prove it

- [ ] Basic prompt composition test.
- [ ] Ordering test.
- [ ] Negative prompt deduplication test.
- [ ] Missing element warning test.
- [ ] Deterministic output test.
- [ ] Saved composed prompt test.

---

# Phase 5 — Real worker API

## 5.1 Replace fake worker endpoints with real service boundaries

### TODO

- [ ] Remove fake generation behaviour from production worker.
- [ ] Keep test fixtures only in tests.
- [ ] Add real job queue.
- [ ] Add persistent job metadata.
- [ ] Add progress events.
- [ ] Add cancellation.
- [ ] Add structured error responses.

### Junie prompt

```text
Replace fake Python worker generation endpoints with real service boundaries.

Keep the existing API routes stable, but remove production fake generation.

Implement:

- real GenerationEngine interface
- real JobQueue
- job status tracking
- progress event tracking
- cancellation support
- output directory creation
- metadata writing
- structured errors
- production rejection of fake generation engine

The worker does not need to generate final LTX video in this task yet, but it must no longer pretend to do so. If the real LTX engine is not configured, the endpoint must return a clear capability/configuration error.

Add tests for all endpoints.
```

### Tests to prove it

- [ ] `/health` test.
- [ ] `/hardware` test.
- [ ] `/models` test.
- [ ] Generation without configured engine returns explicit error.
- [ ] Job queue creates real job object.
- [ ] Cancel job test.
- [ ] Structured error schema test.

---

## 5.2 Add worker API contract tests

### TODO

- [ ] Add OpenAPI validation.
- [ ] Add request/response schema tests.
- [ ] Add backward compatibility checks.
- [ ] Add invalid payload tests.

### Junie prompt

```text
Add API contract tests for the Python worker.

For every worker endpoint, add tests that validate:

- success response schema
- error response schema
- invalid payload handling
- missing required field handling
- stable field names expected by the SwiftUI app

Generate or validate against OpenAPI where practical.

Do not change public endpoint names unless absolutely required. If a change is needed, update SwiftUI client code and documentation in the same commit.
```

### Tests to prove it

- [ ] Contract tests pass.
- [ ] Invalid payloads return 422 or structured application errors.
- [ ] Swift client schema expectations documented.

---

# Phase 6 — Real hardware profiler

## 6.1 Replace mocked hardware profile

### TODO

- [ ] Detect Apple Silicon.
- [ ] Detect CPU/GPU info where available.
- [ ] Detect unified memory.
- [ ] Detect free disk space.
- [ ] Detect macOS version.
- [ ] Detect Python version.
- [ ] Detect MLX availability.
- [ ] Return actionable compatibility status.

### Junie prompt

```text
Replace the mocked hardware profile with real Mac hardware detection.

Implement hardware profiling in the Python worker and expose it through /hardware.

Detect:

- operating system
- macOS version
- Apple Silicon or unsupported architecture
- total unified memory
- available memory if practical
- free disk space for model directory and output directory
- Python version
- MLX installed or missing
- PyTorch installed or missing if required by conversion path
- ffmpeg availability

Return a compatibility result:

- ready
- warning
- unsupported

Include actionable messages, for example:

- MLX is not installed
- ffmpeg is missing
- this Mac has limited memory; use distilled or quantised model
- model directory does not have enough free disk space

Add unit tests by mocking system calls.
```

### Tests to prove it

- [ ] Apple Silicon detection test.
- [ ] Unsupported architecture test.
- [ ] Missing MLX test.
- [ ] Missing ffmpeg test.
- [ ] Low disk space warning test.
- [ ] Worker `/hardware` returns real structure.

---

# Phase 7 — Real Model Manager

## 7.1 Replace fake model list with real model registry

### TODO

- [ ] Create model registry JSON.
- [ ] Define local model profiles.
- [ ] Detect installed models by files/checksums.
- [ ] Show missing models.
- [ ] Validate required files.
- [ ] Add model status.

### Junie prompt

```text
Replace fake model profiles with a real model registry and installed-model detection.

Create a model registry file that defines supported model profiles, for example:

- LTX-2.3 Distilled
- LTX-2.3 Dev
- LTX-2.3 Quantised
- Spatial Upscaler
- Temporal Upscaler
- Camera Control LoRA
- Pose Control LoRA

For each profile define:

- id
- display name
- description
- expected files
- optional checksum field
- estimated memory requirement
- supported generation modes
- recommended hardware profile
- local path
- install status

Implement model scanning against the configured model directory.

The app must show real installed/missing status instead of fake cards.

Add tests using temporary model directories with fake test files. These test files are fixtures only and must not be treated as real models.
```

### Tests to prove it

- [ ] Registry parsing test.
- [ ] Missing model test.
- [ ] Installed model detection test.
- [ ] Missing required file test.
- [ ] Swift Model Manager displays real worker data.

---

## 7.2 Add manual model import

### TODO

- [ ] Allow user to select model folder.
- [ ] Validate required files.
- [ ] Copy or reference model folder.
- [ ] Update model status.
- [ ] Show errors clearly.

### Junie prompt

```text
Implement manual model import.

In the SwiftUI Model Manager, allow the user to select a local model folder. Send the selected path to the worker for validation.

The worker must validate the folder against known model profiles and return:

- matched model profile
- missing files
- warnings
- whether the model can be used

The app must allow the user to either copy the model into the configured model directory or reference it in place.

Add tests for model folder validation and UI/service integration where practical.
```

### Tests to prove it

- [ ] Valid model folder accepted.
- [ ] Invalid model folder rejected.
- [ ] Missing file list returned.
- [ ] App updates model status after import.

---

# Phase 8 — Real MLX/LTX engine integration

## 8.1 Select and isolate the LTX backend adapter

### TODO

- [ ] Decide exact Python package or local module for MLX/LTX generation.
- [ ] Encapsulate it behind `GenerationEngine`.
- [ ] Do not leak library-specific details into API routes.
- [ ] Add capability detection.
- [ ] Add clear dependency errors.

### Junie prompt

```text
Integrate the selected MLX/LTX backend behind a clean adapter.

Do not spread MLX/LTX library calls throughout the worker. Create an adapter class behind the GenerationEngine interface.

The adapter must expose:

- capabilities()
- load_model(model_profile)
- unload_model(model_id)
- generate_text_to_video(request)
- generate_image_to_video(request)
- generate_audio_to_video(request) if supported
- generate_retake(request) if supported

If a feature is unsupported by the selected backend, return an explicit UnsupportedCapabilityError with a clear user-facing message.

Add dependency checks so missing MLX/LTX packages produce actionable errors.

Document the selected backend in docs/generation-engine.md.
```

### Tests to prove it

- [ ] Adapter capability test.
- [ ] Missing dependency error test.
- [ ] Unsupported capability error test.
- [ ] API routes do not import MLX/LTX directly.

---

## 8.2 Implement real text-to-video job execution

### TODO

- [ ] Accept composed prompt.
- [ ] Validate model supports text-to-video.
- [ ] Load model.
- [ ] Run generation.
- [ ] Write output video.
- [ ] Write preview image.
- [ ] Write metadata.
- [ ] Emit progress stages.
- [ ] Return output paths.

### Junie prompt

```text
Implement real text-to-video generation through the MLX/LTX adapter.

The endpoint POST /generate/text-to-video must:

1. Validate the request.
2. Validate selected model profile.
3. Validate model files exist.
4. Create a real generation job.
5. Compose or accept the composed prompt from the app.
6. Load the selected LTX model through MLX.
7. Run text-to-video generation.
8. Emit progress updates.
9. Save output.mp4 or the configured output format.
10. Save preview.jpg.
11. Save metadata.json.
12. Save composed-prompt.md.
13. Return job completion status and output paths.

If generation fails, return a structured error and keep failure metadata.

Add tests:

- unit tests with a fake adapter in test mode only
- integration test that verifies job lifecycle without production mocks
- optional slow/manual test for real model generation, marked separately so CI does not require downloading huge models
```

### Tests to prove it

- [ ] Request validation test.
- [ ] Model missing test.
- [ ] Job lifecycle test.
- [ ] Metadata written test.
- [ ] Failure metadata test.
- [ ] Manual real generation test documented.

---

## 8.3 Implement real image-to-video job execution

### TODO

- [x] Accept input image.
- [x] Validate file exists.
- [x] Validate image format.
- [ ] Copy image into project assets if needed.
- [x] Run image-to-video if supported.
- [x] Save metadata and outputs.

### Junie prompt

```text
Implement real image-to-video generation.

The endpoint POST /generate/image-to-video must:

1. Accept prompt, composed prompt, model profile, input image path, duration, resolution and generation settings.
2. Validate the input image exists and is readable.
3. Validate the selected backend supports image-to-video.
4. Run the generation through the MLX/LTX adapter.
5. Save output video, preview image, metadata and composed prompt.
6. Return clear UnsupportedCapabilityError if the selected backend does not support image-to-video.

Add tests for:

- missing input image
- invalid image file
- unsupported capability
- successful lifecycle with test adapter
- metadata contains image reference hash/path
```

### Tests to prove it

- [x] Missing image test.
- [x] Invalid image test.
- [x] Unsupported capability test.
- [x] Successful image-to-video lifecycle test.
- [x] Metadata contains input image reference.

---

## 8.4 Implement honest audio-to-video and retake behaviour

### TODO

- [ ] Do not fake audio-to-video.
- [ ] Do not fake retake.
- [ ] Implement if backend supports it.
- [ ] Otherwise return explicit unsupported capability.
- [ ] UI must disable unsupported buttons or show explanation.

### Junie prompt

```text
Remove all fake audio-to-video and retake behaviour.

If the selected MLX/LTX backend supports audio-to-video or retake, implement them through the GenerationEngine adapter.

If not supported, the worker must return UnsupportedCapabilityError and the SwiftUI app must show the feature as unavailable with a clear explanation.

The UI must not pretend these features work.

Add tests proving:

- unsupported capabilities return structured errors
- unsupported buttons are disabled or guarded in the app
- no fake output files are created
```

### Tests to prove it

- [ ] Audio-to-video unsupported test or real lifecycle test.
- [ ] Retake unsupported test or real lifecycle test.
- [ ] UI capability guard test.
- [ ] No fake output file test.

---

# Phase 9 — Real job queue and progress

## 9.1 Implement durable job metadata

### TODO

- [ ] Store job metadata on disk.
- [ ] Recover jobs after worker restart.
- [ ] Mark interrupted jobs.
- [ ] Save logs per job.

### Junie prompt

```text
Implement durable generation job metadata.

Every job must be stored on disk under the relevant project generation folder or worker job directory.

Persist:

- job id
- project id
- scene id
- status
- request summary
- model profile
- composed prompt path
- output paths
- started_at
- completed_at
- error details if failed
- progress events

If the worker restarts, it must be able to read existing job metadata and mark interrupted running jobs as interrupted instead of losing them.

Add tests using temporary directories.
```

### Tests to prove it

- [ ] Job metadata written test.
- [ ] Failed job metadata test.
- [ ] Worker restart recovery test.
- [ ] Interrupted job marking test.

---

## 9.2 Add progress streaming to SwiftUI

### TODO

- [ ] Worker emits progress events.
- [ ] SwiftUI receives progress.
- [ ] Render Queue updates live.
- [ ] User can cancel.
- [ ] Cancel propagates to worker.

### Junie prompt

```text
Implement real progress streaming from the Python worker to the SwiftUI app.

Use server-sent events, polling, WebSocket, or another simple local mechanism. Choose the simplest reliable approach for local macOS use.

Progress events must include:

- job id
- stage
- percentage if known
- message
- timestamp

The SwiftUI Render Queue must update live and allow cancellation.

Cancellation must propagate to the worker and mark the job as cancelled.

Add tests for progress event creation, polling/streaming client behaviour where practical, and cancellation state transitions.
```

### Tests to prove it

- [ ] Progress event schema test.
- [ ] Job state transition test.
- [ ] Cancel running job test.
- [ ] Swift GenerationClient progress parsing test.

---

# Phase 10 — SwiftUI app integration

## 10.1 Replace mock GenerationClient with real worker client

### TODO

- [ ] Use real HTTP client.
- [ ] Load worker health.
- [ ] Load hardware profile.
- [ ] Load model profiles.
- [ ] Submit generation jobs.
- [ ] Poll/stream job progress.
- [ ] Handle errors.

### Junie prompt

```text
Replace the mock SwiftUI GenerationClient with a real local worker HTTP client.

The SwiftUI app must call the Python worker for:

- /health
- /hardware
- /models
- /generate/text-to-video
- /generate/image-to-video
- /jobs/{job_id}
- /jobs/{job_id}/cancel

Implement typed request and response models using Codable.

Add robust error handling:

- worker not running
- worker unhealthy
- invalid response
- unsupported capability
- missing model
- generation failed
- generation cancelled

The UI must show friendly messages for each error.

Add unit tests for response decoding and error mapping.
```

### Tests to prove it

- [ ] Health response decode test.
- [ ] Model response decode test.
- [ ] Error response decode test.
- [ ] Worker unavailable error mapping test.
- [ ] Generation request encoding test.

---

## 10.2 Add worker lifecycle management

### TODO

- [ ] App detects worker not running.
- [ ] App can start worker script.
- [ ] App can reconnect.
- [ ] App shows worker status.
- [ ] Worker logs accessible.

### Junie prompt

```text
Implement worker lifecycle support in the SwiftUI app.

The app must detect whether the local Python worker is running. If it is not running, the UI should show a clear state:

"Local generation worker is not running."

Provide actions:

- Start Worker
- Retry Connection
- Open Setup Instructions
- View Logs

Implement starting the worker through a configured script path for development mode. For production packaging, keep the implementation abstract so a bundled worker can be added later.

Add tests for worker status state transitions and error messages.
```

### Tests to prove it

- [ ] Worker offline state test.
- [ ] Worker online state test.
- [ ] Retry connection test.
- [ ] Start worker command construction test.

---

# Phase 11 — Real media handling

## 11.1 Implement preview playback from real generated files

### TODO

- [ ] Store output path in generation metadata.
- [ ] Display video in preview canvas.
- [ ] Display preview image when video not loaded.
- [ ] Handle missing file.
- [ ] Handle unsupported codec.

### Junie prompt

```text
Implement real generated media preview in the SwiftUI app.

When a generation completes, the app must attach the generation metadata to the scene and display the generated video in the Preview Canvas.

Use the output path returned by the worker.

Handle:

- video file exists
- video file missing
- preview image exists
- preview image missing
- unsupported media format

Add user-friendly errors and recovery actions.

Add tests for metadata parsing and missing-file handling.
```

### Tests to prove it

- [ ] Generation metadata attached to scene.
- [ ] Existing output file resolves.
- [ ] Missing output file warning.
- [ ] Preview image fallback test.

---

## 11.2 Implement deterministic brand overlays

### TODO

- [ ] Add title card overlay support.
- [ ] Add logo overlay support.
- [ ] Add lower third overlay support.
- [ ] Do not rely on AI model for text rendering.
- [ ] Use normal video composition/export.

### Junie prompt

```text
Implement deterministic brand overlays for exports.

Brand Kit elements must be applied by the export renderer, not generated by the AI model.

Support:

- logo overlay
- watermark
- title card
- outro card
- lower third text
- subtitle style placeholder

The overlay system must read BrandKit settings from the Continuity Library.

Add tests proving overlay instructions are generated from BrandKit data. If full video overlay testing is difficult in CI, add unit tests for composition instructions and a manual smoke test.
```

### Tests to prove it

- [ ] BrandKit overlay instruction test.
- [ ] Missing logo handling test.
- [ ] Export metadata includes overlay settings.
- [ ] Manual video overlay smoke test documented.

---

# Phase 12 — Real export pipeline

## 12.1 Implement MP4 export from timeline

### TODO

- [ ] Read timeline clips.
- [ ] Validate clip files.
- [ ] Concatenate clips.
- [ ] Apply brand overlays where possible.
- [ ] Encode MP4.
- [ ] Save export metadata.
- [ ] Show export progress.

### Junie prompt

```text
Implement real MP4 export from the project timeline.

The export pipeline must:

1. Read timeline.json.
2. Resolve scene generation outputs.
3. Validate all required video files exist.
4. Concatenate clips in timeline order.
5. Apply deterministic brand overlays where supported.
6. Encode an MP4 output using ffmpeg or AVFoundation.
7. Save export metadata.
8. Return the final export path to the app.

If a clip is missing, fail with a clear error listing the missing scene/clip.

Add tests for timeline validation and export command construction. Add an integration test using tiny fixture videos if practical.
```

### Tests to prove it

- [ ] Timeline validation test.
- [ ] Missing clip test.
- [ ] Export command construction test.
- [ ] Tiny video concatenation integration test.
- [ ] Export metadata written test.

---

# Phase 13 — UI polish and usability proof

## 13.1 Replace placeholder screens with working screens

### TODO

- [ ] Home Dashboard uses real projects.
- [ ] Project Studio uses real project data.
- [ ] Continuity Library uses real storage.
- [ ] Model Manager uses worker model data.
- [ ] Render Queue uses real job data.
- [ ] Settings uses real config.

### Junie prompt

```text
Replace all placeholder SwiftUI screens with working data-backed screens.

The following screens must use real services instead of mock data:

- Home Dashboard
- Project Studio
- Continuity Library
- Model Manager
- Render Queue
- Settings

Preview-only sample data may remain inside SwiftUI previews, but production views must use real services.

Add tests for ViewModels where practical.

Update docs/user-experience.md with screenshots placeholders or descriptions of the final screens.
```

### Tests to prove it

- [ ] HomeViewModel loads real recent projects.
- [ ] ContinuityLibraryViewModel loads real elements.
- [ ] ModelManagerViewModel loads worker model profiles.
- [ ] RenderQueueViewModel loads real jobs.
- [ ] SettingsViewModel loads config.

---

## 13.2 Add user-friendly error catalogue

### TODO

- [ ] Define app error types.
- [ ] Map worker errors to user messages.
- [ ] Add recovery suggestions.
- [ ] Add tests.

### Junie prompt

```text
Create a user-friendly error catalogue for AI Studio Local.

Map technical errors to helpful messages and recovery actions.

Cover at least:

- worker not running
- MLX missing
- ffmpeg missing
- unsupported Mac
- insufficient memory
- model missing
- model incomplete
- generation unsupported
- generation failed
- generation cancelled
- project corrupt
- missing continuity element
- missing media file
- export failed

Each error must have:

- technical code
- user-facing title
- user-facing message
- suggested recovery actions
- optional documentation link

Add tests proving important errors map correctly.
```

### Tests to prove it

- [ ] Worker unavailable mapping test.
- [ ] Missing model mapping test.
- [ ] Unsupported capability mapping test.
- [ ] Export failed mapping test.

---

# Phase 14 — End-to-end tests and smoke tests

## 14.1 Add Python worker test suite

### TODO

- [ ] Unit tests.
- [ ] API tests.
- [ ] Contract tests.
- [ ] File persistence tests.
- [ ] Job lifecycle tests.

### Junie prompt

```text
Create a comprehensive Python worker test suite.

Use pytest.

Test categories:

- config tests
- hardware profiler tests
- model registry tests
- API route tests
- schema validation tests
- job queue tests
- job persistence tests
- prompt/generation request validation tests
- error response tests
- export pipeline tests

Ensure tests do not require downloading real large models. Use test fixtures and test adapters only in test mode.

Add a make/script command to run all worker tests.
```

### Tests to prove it

- [ ] `pytest` passes.
- [ ] Test coverage includes API, config, model registry, queue, persistence.

---

## 14.2 Add Swift test suite

### TODO

- [ ] Domain model tests.
- [ ] Store tests.
- [ ] ViewModel tests.
- [ ] Worker client tests.
- [ ] Prompt Composer tests if Swift-side.
- [ ] Error mapping tests.

### Junie prompt

```text
Create a Swift test suite for the macOS app.

Test categories:

- domain model Codable tests
- project store tests using temporary folders
- continuity store tests using temporary folders
- generation client request/response decoding tests
- model manager ViewModel tests
- render queue ViewModel tests
- error mapping tests
- prompt composer tests if implemented in Swift

Keep SwiftUI view snapshot testing optional. Focus first on logic and data correctness.

Add a script command to run Swift tests.
```

### Tests to prove it

- [ ] Swift tests pass in Xcode or command line.
- [ ] Codable roundtrip tests pass.
- [ ] Store tests pass.
- [ ] Worker client tests pass.

---

## 14.3 Add local end-to-end smoke test

### TODO

- [ ] Start worker.
- [ ] Create temp project.
- [ ] Create continuity elements.
- [ ] Compose prompt.
- [ ] Submit generation with test adapter.
- [ ] Receive job completion.
- [ ] Attach output to scene.
- [ ] Export tiny MP4 if fixture media available.

### Junie prompt

```text
Add a local end-to-end smoke test that proves the application workflow without requiring a real large LTX model download.

The smoke test may use a test adapter, but only in test mode.

The smoke test must:

1. Start or instantiate the worker in test mode.
2. Create a temporary project folder.
3. Create at least one continuity character and one style.
4. Create a scene.
5. Compose the prompt.
6. Submit a text-to-video generation job.
7. Produce a tiny valid fixture video output through the test adapter.
8. Save generation metadata.
9. Attach generation to the scene.
10. Export or validate timeline output if possible.

This test proves the wiring works. It must not be available in production mode.
```

### Tests to prove it

- [ ] End-to-end test passes in CI.
- [ ] Production mode rejects test adapter.
- [ ] Metadata and project files are created.

---

## 14.4 Add manual real-model test checklist ✓

### TODO

- [✓] Create manual test doc.
- [✓] Include hardware requirements.
- [✓] Include model installation steps.
- [✓] Include text-to-video test.
- [✓] Include image-to-video test.
- [✓] Include export test.

### Junie prompt

```text
Create docs/manual-real-model-test-checklist.md.

This checklist is for testing with real LTX/MLX models on an Apple Silicon Mac.

Include:

- hardware requirements
- Python environment requirements
- MLX installation check
- ffmpeg installation check
- model directory setup
- model validation
- text-to-video test prompt
- image-to-video test prompt
- expected output files
- expected metadata files
- troubleshooting section

Do not make CI depend on real large model downloads.
```

### Tests to prove it

- [ ] Manual checklist exists.
- [ ] Checklist references actual app/worker commands.
- [ ] Checklist includes expected files and troubleshooting.

---

# Phase 15 — CI and quality gates

## 15.1 Update CI for real tests

### TODO

- [ ] Run Python lint.
- [ ] Run Python tests.
- [ ] Run schema validation.
- [ ] Run Swift lint if available.
- [ ] Run Swift tests if practical on macOS runner.
- [ ] Upload test artifacts on failure.

### Junie prompt

```text
Update GitHub Actions CI to run the real quality gates.

CI must run:

- Python dependency install
- ruff check
- pytest
- JSON schema validation
- SwiftLint if available
- Swift tests on macOS runner if the Xcode project is present and runnable

CI must not download huge LTX models.

Add caching where sensible.

Upload logs/test artifacts on failure.
```

### Tests to prove it

- [ ] CI passes on clean repo.
- [ ] CI fails on lint error.
- [ ] CI fails on test failure.

---

## 15.2 Add no-mock production guard in CI

### TODO

- [ ] Add script scanning production code for forbidden mock imports.
- [ ] Allow mocks only in previews/tests/fixtures.
- [ ] CI runs guard.

### Junie prompt

```text
Add a CI guard that prevents production code from importing or using mock/test services.

Create scripts/check-no-production-mocks.sh.

The script must scan app and worker production source files for forbidden names/imports such as:

- Mock
- Fake
- Stub
- SampleData
- PreviewFixture
- TestAdapter

Allow these only in:

- tests
- SwiftUI previews
- fixtures
- docs

Make CI run this script.

Document how to add legitimate test fixtures without violating production rules.
```

### Tests to prove it

- [ ] Guard passes current code.
- [ ] Guard fails when mock service is imported in production path.

---

# Phase 16 — Documentation update

## 16.1 Update developer documentation

### TODO

- [ ] Update setup docs.
- [ ] Document worker startup.
- [ ] Document model setup.
- [ ] Document project format.
- [ ] Document continuity library format.
- [ ] Document test strategy.

### Junie prompt

```text
Update all developer documentation to reflect the real implementation.

Update or create:

- docs/development-setup.md
- docs/generation-engine.md
- docs/model-manager.md
- docs/project-format.md
- docs/continuity-library.md
- docs/testing.md
- docs/manual-real-model-test-checklist.md

The docs must explain how to:

- run the SwiftUI app
- run the Python worker
- configure model directories
- import models manually
- create a project
- create continuity elements
- run tests
- run the end-to-end smoke test
- troubleshoot common errors
```

### Tests to prove it

- [ ] Docs reference real commands.
- [ ] Docs do not describe removed mocks as production features.
- [ ] README links to updated docs.

---

# Phase 17 — Final cleanup

## 17.1 Remove obsolete mock code

### TODO

- [ ] Remove unused mock services.
- [ ] Move preview data into preview-only folders.
- [ ] Move test fixtures into test folders.
- [ ] Delete dead code.
- [ ] Run no-mock production guard.

### Junie prompt

```text
Perform final mock cleanup.

Using docs/mock-removal-audit.md, remove all obsolete mock, fake, stub and placeholder production code.

Allowed remaining mock-like code:

- SwiftUI previews
- test fixtures
- test adapters used only in test mode
- documentation examples

After cleanup:

- run all tests
- run no-production-mocks guard
- update docs/mock-removal-audit.md with final status
- remove dead imports
- remove unused files
```

### Tests to prove it

- [ ] No-production-mocks guard passes.
- [ ] All tests pass.
- [ ] Audit file shows all production mocks removed or justified.

---

## 17.2 Create release candidate checklist

### TODO

- [ ] Create `docs/release-candidate-checklist.md`.
- [ ] Include app launch test.
- [ ] Include worker health test.
- [ ] Include model validation test.
- [ ] Include generation test.
- [ ] Include export test.
- [ ] Include Git cleanliness check.

### Junie prompt

```text
Create docs/release-candidate-checklist.md for the first working release candidate.

The checklist must include:

- clean clone setup
- dependency installation
- worker startup
- app startup
- config creation
- model directory configuration
- model validation
- create project
- create continuity character/style/location
- compose prompt
- text-to-video generation with real model if available
- image-to-video generation if supported
- export timeline to MP4
- verify generated metadata
- verify no production mocks
- run all tests
- verify CI passing

This checklist should be practical and executable by a developer on an Apple Silicon Mac.
```

### Tests to prove it

- [ ] Checklist exists.
- [ ] Checklist is linked from README.
- [ ] Checklist uses real commands.

---

# Final master prompt for Junie

Use this when starting the full second-stage implementation.

```text
You are Junie, acting as a senior macOS SwiftUI, Python, MLX, and AI video application engineer.

The AI Studio Local repository already contains the initial project structure and mock application shell. Your task is to turn it into a working application by removing mocks, replacing them with real code, and adding tests that prove the behaviour.

Read first:

- AGENTS.md
- README.md
- ROADMAP.md
- docs/architecture.md
- docs/development-setup.md
- docs/user-experience.md
- docs/continuity-library.md
- this TODO file

Work in very small commits. Do not rewrite the architecture unless required. Preserve the SwiftUI macOS frontend and Python MLX/LTX worker architecture.

The top priorities are:

1. Audit all mocks and placeholders.
2. Add production/mock boundary rules.
3. Implement real configuration.
4. Implement real folder-based project persistence.
5. Implement real JSON-backed Continuity Library persistence.
6. Implement deterministic Prompt Composer.
7. Replace fake worker endpoints with real service boundaries.
8. Implement real hardware profiling.
9. Implement real model registry and model detection.
10. Integrate the selected MLX/LTX backend behind a clean adapter.
11. Implement real text-to-video generation path.
12. Implement image-to-video where supported.
13. Make audio-to-video and retake honest: implement if supported, otherwise return explicit unsupported capability errors.
14. Implement real job queue, progress, cancellation and metadata.
15. Replace the SwiftUI mock client with the real worker client.
16. Display real generated media in the app.
17. Implement MP4 export from timeline.
18. Add comprehensive tests.
19. Add CI quality gates.
20. Remove all production mocks.

Rules:

- No fake generation in production.
- No silent fallback to mocks.
- Test adapters are allowed only in test mode.
- SwiftUI previews may use preview fixtures only.
- Every endpoint must have tests.
- Every store must have tests.
- Every generated output must have metadata.
- Every error must be actionable.
- CI must not require huge model downloads.
- Real model tests may be manual or optional slow tests.

Start with Phase 0 and proceed sequentially. After each phase, run the relevant tests and update the TODO checklist.
```

---

# Recommended commit sequence

```text
docs: add mock removal audit
feat: add environment mode and production mock guard
feat: add real configuration system
feat: implement folder based project persistence
feat: add git friendly project files
feat: implement json backed continuity library
feat: attach continuity elements to scenes
feat: implement deterministic prompt composer
feat: replace fake worker endpoints with real service boundaries
test: add worker api contract tests
feat: implement real hardware profiler
feat: add model registry and installed model detection
feat: add manual model import validation
feat: add mlx ltx generation adapter boundary
feat: implement text to video job lifecycle
feat: implement image to video job lifecycle
feat: add honest unsupported capability handling
feat: persist generation job metadata
feat: stream generation progress to app
feat: replace swift mock generation client
feat: add worker lifecycle management
feat: display generated media in preview canvas
feat: add deterministic brand overlay instructions
feat: implement timeline mp4 export
test: add python worker test suite
test: add swift app test suite
test: add end to end smoke test
ci: run real lint and test gates
ci: add no production mocks guard
docs: update real implementation documentation
refactor: remove obsolete mock production code
docs: add release candidate checklist
```

---

# Final acceptance checklist

Before calling this phase done, verify:

```text
[ ] The app starts.
[ ] The worker starts.
[ ] The app detects worker health.
[ ] The app shows real hardware status.
[ ] The app shows real model status.
[ ] The user can create a project.
[ ] The user can create continuity elements.
[ ] The user can attach continuity elements to a scene.
[ ] The app can compose a prompt.
[ ] The app can submit a generation job.
[ ] The worker creates real job metadata.
[ ] The worker does not fake generation in production.
[ ] Real text-to-video path is implemented or fails with an honest missing-model/dependency error.
[ ] Image-to-video path is implemented or fails with honest unsupported error.
[ ] Audio-to-video does not fake success.
[ ] Retake does not fake success.
[ ] The app can display generated media when available.
[ ] The app can export timeline MP4 from available clips.
[ ] Project files are Git-friendly.
[ ] Continuity Library files are readable JSON.
[ ] All Python tests pass.
[ ] All Swift tests pass where available.
[ ] CI passes.
[ ] No production mocks remain.
[ ] README and docs are updated.
```
