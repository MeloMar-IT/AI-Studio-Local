# AGENTS.md — Junie Coding Agent Instructions

## Ground rules for Junie

Before starting any task, Junie must read:

AGENTS.md
README.md
ROADMAP.md
docs/architecture.md
docs/development-setup.md
docs/user-experience.md
docs/continuity-library.md


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


## Project

**Project name:** AI Studio Local
**Repository name:** `ai-studio-local`
**Primary goal:** Build a native macOS AI video creation application for Apple Silicon that uses LTX video models through MLX, with a strong focus on user experience, local-first workflows, reusable creative elements, and long-term maintainability.

This application must feel like a polished creative Mac application, not a developer demo or thin wrapper around a Python script.

---

## Product Summary

AI Studio Local is a local-first AI video creation studio for macOS. It allows users to generate, edit, retake, extend, and export AI-generated videos using LTX models on Apple Silicon through MLX.

The application supports:

- Text-to-video
- Image-to-video
- Audio-to-video, initially as placeholder if not implemented yet
- Video retake, initially as placeholder if not implemented yet
- Multi-scene projects
- Timeline-based editing
- Local model management
- Generation queue
- Project history
- Reusable creative elements through a Continuity Library
- Brand kits and export templates
- Git-friendly project folders

The application must prioritise ease of use. Advanced model controls must exist, but they must not dominate the default user experience.

---

## Core Product Principle

The user should be able to create a video without understanding MLX, LTX, Python, LoRA files, safetensors, inference steps, samplers, model paths, or generation internals.

The interface should guide the user through clear creative choices:

- What do you want to create?
- Which character should appear?
- Which location should be used?
- Which style should be applied?
- How long should the clip be?
- Should audio be generated?
- Should this stay consistent with previous projects?

Advanced controls should be available only behind progressive disclosure.

---

## Required Repository Structure

Use and maintain the following repository layout unless explicitly instructed otherwise:

```text
ltx-studio-local/
│
├── README.md
├── LICENSE
├── CHANGELOG.md
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
├── SECURITY.md
├── ROADMAP.md
├── AGENTS.md
├── Makefile
├── .gitignore
├── .editorconfig
├── .swiftformat
├── .swiftlint.yml
│
├── .github/
│   ├── workflows/
│   │   ├── macos-build.yml
│   │   ├── lint.yml
│   │   └── release.yml
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   ├── feature_request.md
│   │   └── model_support.md
│   └── pull_request_template.md
│
├── app/
│   ├── AIStudioLocal.xcodeproj
│   ├── AIStudioLocal/
│   │   ├── App/
│   │   ├── DesignSystem/
│   │   ├── Features/
│   │   ├── Domain/
│   │   ├── Services/
│   │   └── Resources/
│   └── AIStudioLocalTests/
│
├── worker/
│   ├── pyproject.toml
│   ├── README.md
│   ├── ai_video_worker/
│   │   ├── main.py
│   │   ├── api.py
│   │   ├── config.py
│   │   ├── logging_config.py
│   │   ├── engine/
│   │   ├── jobs/
│   │   ├── schemas/
│   │   └── utils/
│   └── tests/
│
├── shared/
│   ├── schemas/
│   └── examples/
│
├── docs/
│   ├── architecture.md
│   ├── user-experience.md
│   ├── continuity-library.md
│   ├── model-manager.md
│   ├── generation-engine.md
│   ├── project-format.md
│   ├── plugin-system.md
│   └── development-setup.md
│
├── examples/
│   ├── projects/
│   ├── continuity-libraries/
│   └── prompt-packs/
│
└── scripts/
    ├── bootstrap.sh
    ├── install-worker.sh
    ├── run-worker.sh
    ├── run-app.sh
    ├── format.sh
    ├── lint.sh
    └── test.sh
```

Do not flatten this structure. Do not mix Swift application code with Python worker code.

---

## Application Architecture

The project uses a two-part architecture:

```text
SwiftUI macOS App
        │
        ▼
Application Services
        │
        ├── ProjectStore
        ├── ContinuityStore
        ├── ModelStore
        ├── GenerationClient
        ├── ExportService
        └── HardwareProfiler
        │
        ▼
Local Python Worker
        │
        ├── FastAPI or equivalent local API
        ├── Job Queue
        ├── MLX Runtime
        ├── LTX Pipeline
        ├── LoRA Loader
        ├── Upscaler
        └── Media Encoder
```

The SwiftUI application owns the user experience.
The Python worker owns generation execution.
The shared schemas define contracts between the two.

The GUI must never block while video generation is running.

---

## SwiftUI Application Rules

### General Swift Rules

- Use SwiftUI for the macOS frontend.
- Use Swift Concurrency where appropriate.
- Use `Codable` for persisted domain models.
- Keep business logic out of views.
- Use ViewModels and services.
- Use protocol-based service abstractions where practical.
- Do not hard-code file paths in views.
- Do not hard-code colours or spacing directly in feature views.
- Prefer small, composable views over large monolithic views.
- Keep feature-specific code inside `Features/<FeatureName>/`.

### Required App Areas

The app must include these top-level areas:

- Home Dashboard
- Project Studio
- Continuity Library
- Model Manager
- Render Queue
- Settings

### Required Feature Folders

Inside `app/AIStudioLocal/Features/`, use the following structure:

```text
Features/
├── Home/
├── ProjectStudio/
├── Timeline/
├── Preview/
├── Generation/
├── ContinuityLibrary/
├── ModelManager/
├── RenderQueue/
├── Export/
└── Settings/
```

### Required Domain Models

Inside `app/AIStudioLocal/Domain/`, implement and maintain these models:

- `Project.swift`
- `Scene.swift`
- `GenerationJob.swift`
- `ContinuityElement.swift`
- `CharacterElement.swift`
- `LocationElement.swift`
- `StyleElement.swift`
- `CameraPreset.swift`
- `AudioIdentity.swift`
- `BrandKit.swift`
- `PromptBlock.swift`
- `LoRAReference.swift`
- `ModelProfile.swift`
- `ExportPreset.swift`

### Required Services

Inside `app/AIStudioLocal/Services/`, implement and maintain:

- `ProjectStore.swift`
- `ContinuityStore.swift`
- `ModelStore.swift`
- `GenerationClient.swift`
- `ExportService.swift`
- `FileSystemService.swift`
- `HardwareProfiler.swift`
- `PromptComposer.swift`

Each service should have a clear responsibility.

---

## Design System Rules

The GUI is a major part of the product. Treat the design system as production code.

Create and maintain:

```text
DesignSystem/
├── Colors.swift
├── Typography.swift
├── Spacing.swift
├── Components/
│   ├── PrimaryButton.swift
│   ├── SecondaryButton.swift
│   ├── IconButton.swift
│   ├── ElementChip.swift
│   ├── SceneCard.swift
│   ├── ProjectCard.swift
│   ├── ModelCard.swift
│   ├── ProgressCard.swift
│   ├── InspectorPanel.swift
│   ├── InspectorSection.swift
│   ├── EmptyStateView.swift
│   ├── DropZone.swift
│   ├── TimelineClip.swift
│   ├── PreviewPlayer.swift
│   └── StatusBadge.swift
└── Icons/
```

### GUI Requirements

- Dark mode first.
- Clean native macOS look and feel.
- No cluttered developer-style screens.
- Use cards, chips, sidebars, inspectors, and timeline components consistently.
- Prefer user-friendly labels over technical model language.
- Hide advanced generation settings by default.
- Show helpful empty states.
- Show clear generation progress.
- Show useful, actionable error messages.

### UX Language Rules

Avoid raw technical labels in beginner-facing screens.

Bad:

```text
CFG scale
Sampler
Checkpoint
Latent upscaler
```

Good:

```text
Prompt strength
Quality profile
Model profile
Enhance details
```

Advanced mode may expose technical labels, but they must be clearly grouped under an Advanced section.

---

## Continuity Library Requirements

The Continuity Library is a core feature. It allows users to reuse elements across projects.

It must support these element types:

- Character
- Location
- Visual Style
- Camera Preset
- Audio Identity
- Brand Kit
- Prompt Block
- LoRA Reference
- Export Template

### Continuity Element Base Fields

Every continuity element must include:

```json
{
  "id": "string",
  "type": "string",
  "name": "string",
  "description": "string",
  "prompt_block": "string",
  "negative_prompt": "string",
  "tags": [],
  "assets": [],
  "created_at": "datetime",
  "modified_at": "datetime"
}
```

### Continuity Library GUI

The Continuity Library must provide:

- Category sidebar
- List/detail layout
- Create/edit/delete actions
- Search
- Tag filtering
- Helpful empty states
- Visual element chips
- Import/export of library folders
- Default starter elements

### Scene Integration

A scene must be able to attach continuity elements.

Example attached elements:

```text
[Senior SRE Marcel] [High-Rise IT Office] [Warm Pixar-like IT] [Slow Dolly] [MeloMar-IT]
```

Attached elements must be displayed as chips in the Scene Inspector.

### Consistency Locks

Scenes must support these locks:

- Character identity
- Clothing
- Location
- Visual style
- Brand overlay
- Audio identity
- Seed
- Camera behaviour

Locks control what should remain stable across generations.

---

## Prompt Composer Requirements

The `PromptComposer` service is responsible for composing the final prompt sent to the generation worker.

It must combine:

- Scene prompt
- Character prompt blocks
- Location prompt blocks
- Style prompt blocks
- Camera prompt blocks
- Audio prompt blocks
- Brand instructions
- Negative prompts
- Consistency locks
- Model-specific formatting if needed

The composed prompt must be visible to the user through a **View Composed Prompt** action.

Do not send raw scene prompts directly to the worker when continuity elements are attached. Always use the composed prompt.

---

## Project Format Requirements

Projects must be stored as folders, not opaque databases.

Use this structure:

```text
MyProject.ltxproject/
│
├── project.json
├── timeline.json
├── scenes/
│   ├── scene-001/
│   │   ├── scene.json
│   │   ├── prompt.md
│   │   ├── generations/
│   │   │   ├── gen-001/
│   │   │   │   ├── output.mp4
│   │   │   │   ├── preview.jpg
│   │   │   │   ├── metadata.json
│   │   │   │   └── composed-prompt.md
│   │   │   └── gen-002/
│   │   └── references/
│   └── scene-002/
│
├── assets/
│   ├── images/
│   ├── audio/
│   ├── video/
│   └── overlays/
│
├── exports/
│   ├── final-linkedin.mp4
│   └── final-youtube.mp4
│
└── README.md
```

The project folder must be Git-friendly. JSON should be formatted and readable.

Large generated media files should not be committed by default unless the user configures Git LFS.

---

## Python Worker Rules

The Python worker is responsible for local generation execution.

### Required Technology

- Python 3.11 or newer
- FastAPI or equivalent local API
- Pydantic schemas
- Structured logging
- Pytest tests
- Ruff formatting/linting

### Required Worker Endpoints

Implement and maintain these endpoints:

```text
GET  /health
GET  /hardware
GET  /models
POST /models/load
POST /models/unload
POST /generate/text-to-video
POST /generate/image-to-video
POST /generate/audio-to-video
POST /generate/retake
GET  /jobs/{job_id}
POST /jobs/{job_id}/cancel
GET  /jobs/{job_id}/events
```

For MVP, audio-to-video and retake may return clear `not_implemented` responses, but the API shape must exist.

### Worker Behaviour

- Never block API request handling with long-running generation.
- Every generation request must create a job.
- Every job must have a stable job ID.
- Every job must expose status.
- Every job must emit progress.
- Every job must support cancellation.
- Every completed job must save metadata.
- Every failed job must return a clear and actionable error.

### Generation Stages

Use clear progress stages:

```text
preparing_prompt
checking_hardware
loading_model
preparing_inputs
generating_video
generating_audio
upscaling
encoding_output
saving_metadata
completed
failed
cancelled
```

---

## Generation Metadata Requirements

Every generated clip must save a `metadata.json` file containing:

- Generation ID
- Project ID
- Scene ID
- Created timestamp
- App version
- Worker version
- Model profile
- Model path or model ID
- Model checksum if available
- LoRAs used
- Prompt
- Composed prompt
- Negative prompt
- Seed
- Duration
- Resolution
- Aspect ratio
- FPS
- Steps
- Guidance setting
- Audio setting
- Input image path if used
- Input audio path if used
- Input video path if used
- Output video path
- Preview image path
- Generation duration
- Error details if failed

Reproducibility matters. Never discard generation settings.

---

## Model Manager Requirements

The Model Manager must make local model setup easy.

It must show:

- Installed models
- Available models
- Recommended model for current Mac
- Disk usage
- Model health
- Missing files
- Compatibility warnings

Model profiles should use friendly labels:

- Fast Draft
- Balanced
- Production
- Portrait
- Audio-Video
- Upscaler
- Control LoRA
- Style LoRA

Do not force the user to manually understand checkpoint names in the default UI.

---

## Hardware Profiler Requirements

The app must detect or represent:

- Apple Silicon availability
- macOS version
- Unified memory
- Free memory if available
- Free disk space
- Recommended generation profile
- Whether local mode is ready

When memory is insufficient, provide helpful suggestions:

- Use Fast Draft
- Lower resolution
- Shorten duration
- Use quantised model
- Close memory-heavy apps

---

## Timeline Requirements

For MVP, the timeline can be simple.

Required timeline capabilities:

- Show scenes as clips
- Reorder scenes
- Preview selected scene
- Select generation version
- Export scenes in order

Later timeline capabilities:

- Trim
- Split
- Retake range
- Extend clip
- Fill gap
- Audio track
- Overlay track

Do not build a complex professional editor before the core workflow works.

---

## Export Requirements

MVP export must support:

- Export selected scene
- Export full project timeline
- MP4 output
- Basic brand overlay
- Basic title card
- Basic outro card

Brand logos, text, subtitles, lower-thirds, and calls-to-action must be applied deterministically in the export layer where possible. Do not rely on AI generation for accurate text or logos.

---

## Git and Commit Rules

Use small, focused commits.

Follow conventional commit style:

```text
feat: add continuity library character editor
fix: prevent generation queue from blocking UI
docs: document project folder format
refactor: extract prompt composer service
test: add scene serialization tests
chore: update lint configuration
```

Do not mix unrelated changes in one commit.

Do not commit generated videos, model weights, caches, local virtual environments, derived Xcode data, or secrets.

---

## Branching Model

Use:

```text
main       stable releases only
develop    integration branch
feature/*  new features
fix/*      bug fixes
release/*  release preparation
```

When implementing a feature, create or work within a feature branch.

---

## Quality Gates

Before marking work complete, run or ensure equivalent checks:

```bash
scripts/format.sh
scripts/lint.sh
scripts/test.sh
```

For Swift:

- Build must pass.
- SwiftLint must pass where configured.
- Unit tests must pass where present.

For Python:

- Ruff must pass.
- Pytest must pass.
- Pydantic schemas must validate representative requests and responses.

Documentation must be updated when behaviour, architecture, project format, or API contracts change.

---

## Testing Requirements

### Swift Tests

Add tests for:

- Project encoding/decoding
- Scene encoding/decoding
- Continuity element persistence
- Prompt composition
- Generation client request mapping
- Project folder creation

### Python Tests

Add tests for:

- `/health`
- `/hardware`
- `/models`
- Job creation
- Job status changes
- Cancellation
- Request validation
- Error responses
- Metadata writing

Do not leave new logic untested unless explicitly justified.

---

## Documentation Rules

Whenever you add or change important functionality, update the relevant documentation.

Important docs:

- `docs/architecture.md`
- `docs/user-experience.md`
- `docs/continuity-library.md`
- `docs/model-manager.md`
- `docs/generation-engine.md`
- `docs/project-format.md`
- `docs/development-setup.md`

Documentation should be practical and useful for future maintainers.

Avoid vague documentation like:

```text
This module handles stuff.
```

Use concrete descriptions:

```text
The PromptComposer builds the final prompt sent to the worker by combining the scene prompt, attached continuity elements, negative prompts, and consistency locks.
```

---

## Security and Privacy Requirements

This application is local-first.

Default behaviour:

- Do not send prompts to external services.
- Do not send images to external services.
- Do not send audio to external services.
- Do not send generated videos to external services.
- Do not collect telemetry unless explicitly added later with user consent.

If cloud fallback is ever implemented, it must be explicit and opt-in.

Secrets, API keys, model tokens, or credentials must never be committed.

---

## Error Message Rules

All user-facing errors must be actionable.

Bad:

```text
Generation failed.
```

Good:

```text
This generation needs more memory than your Mac currently has available.
Try using the Fast Draft model, lowering the resolution to 720p, or reducing the duration to 5 seconds.
```

Worker errors must include:

- Error code
- Human-readable message
- Technical detail for logs
- Suggested user action where possible

---

## Performance Rules

- The GUI must remain responsive during generation.
- Long-running tasks must run outside the main thread.
- Worker jobs must be cancellable.
- Avoid loading large media files fully into memory when streaming is possible.
- Avoid blocking SwiftUI views with synchronous file or network calls.
- Model loading should be visible as a progress stage.

---

## Accessibility and Usability Rules

- Use readable labels.
- Use accessible button names.
- Do not rely only on colour to communicate status.
- Provide keyboard-friendly navigation where practical.
- Keep contrast high enough for dark mode.
- Keep empty states helpful.
- Avoid overwhelming the user with too many controls at once.

---

## MVP Scope

For the first working version, implement:

- Native macOS SwiftUI shell
- Home Dashboard
- New Project flow
- Project save/load
- Scene list
- Basic timeline
- Continuity Library v1
- Prompt Composer v1
- Model Manager v1 with mock model data
- Python worker skeleton
- Mock generation jobs
- Generation queue UI
- MP4 output placeholder or mock result
- Good error and empty states

Do not implement complex timeline editing, LoRA training, cloud collaboration, render farms, or marketplace features in the MVP.

---

## Later Features

After MVP, add:

- Real MLX/LTX text-to-video
- Real MLX/LTX image-to-video
- Audio-to-video
- Retake selected range
- Keyframe interpolation
- LoRA control
- Model download manager
- Upscaler pipeline
- Prompt optimiser
- Version comparison
- Brand overlays
- Final Cut / DaVinci export support
- Multi-Mac render queue

---

## Implementation Order

Follow this order unless the user explicitly instructs otherwise:

1. Repository skeleton
2. SwiftUI app shell
3. Design system
4. Domain models
5. Project persistence
6. Continuity Library
7. Prompt Composer
8. Python worker skeleton
9. Mock generation flow
10. Render queue UI
11. Model Manager
12. Timeline MVP
13. Export MVP
14. Real MLX/LTX integration

Do not start with real MLX/LTX generation before the application shell, project format, and continuity system exist.

---

## Coding Agent Behaviour

When working on this repository:

- Make the smallest useful change that moves the project forward.
- Keep code clean and readable.
- Prefer explicit names over clever abstractions.
- Do not introduce unnecessary frameworks.
- Do not rewrite large areas without a clear reason.
- Preserve existing architecture unless changing it is explicitly required.
- Update tests and documentation with functional changes.
- Keep user experience quality high.
- Keep local-first privacy intact.

If there is ambiguity, choose the option that makes the application easier for a non-technical creator to use while preserving advanced capability for expert users.

---

## Definition of Done

A task is complete only when:

- The feature works or a clear placeholder is implemented.
- The UI is clean and consistent with the design system.
- The app does not block during long-running operations.
- Relevant models/services are tested.
- Documentation is updated if needed.
- No generated media, model weights, secrets, or local caches are committed.
- The code fits the repository architecture.
- Errors are helpful and actionable.
- The change is ready for Git review.

---

## Non-Negotiable Rules

- Do not build a cluttered technical interface.
- Do not put business logic inside SwiftUI views.
- Do not make generation block the GUI.
- Do not store projects in an opaque database.
- Do not ignore the Continuity Library.
- Do not send user data to external services by default.
- Do not commit model weights or generated videos by default.
- Do not expose advanced model internals in the beginner workflow.
- Do not skip documentation for architectural changes.
- Do not mark mock functionality as real functionality.

