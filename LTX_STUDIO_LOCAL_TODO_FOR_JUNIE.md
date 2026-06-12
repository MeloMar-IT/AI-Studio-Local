# LTX Studio Local — Extensive TODO List for Junie

This file is intended for **Junie, the IntelliJ coding agent**, to build the project in small, safe, reviewable steps.

The project is a **Git-maintained local-first AI video creation application for Apple Silicon**, using:

- **SwiftUI macOS app** for the graphical user interface
- **Python worker** for MLX/LTX video generation
- **Local project folders** for Git-friendly storage
- **Continuity Library** for reusable characters, locations, styles, camera presets, brand kits, audio identities, prompt blocks and LoRA references

The user experience must be excellent. The app should feel like a polished Mac creative application, not a technical demo.

---

## Core product goal

Build **LTX Studio Local**, a local-first AI video creation studio for Mac.

The app allows users to:

- Create AI video from text
- Animate images into video
- Later create video from audio
- Later retake/fix parts of existing videos
- Build videos from multiple scenes
- Reuse characters, styles, locations and branding across many projects
- Manage local LTX/MLX models
- Export final videos

The first versions may use mock generation. Real LTX/MLX generation must be added later behind a stable worker API.

---

## Important instruction for Junie

Do **not** try to build the whole application in one step.

Work in small commits. Every step must leave the repository in a working state.

After every phase:

1. Run formatting
2. Run linting where available
3. Run tests where available
4. Update documentation if the structure changed
5. Make sure the app or worker still starts
6. Commit with a meaningful conventional commit message

Use conventional commits:

```text
feat: add project model
fix: handle missing project folder
refactor: extract prompt composer
 docs: document continuity library
 test: add project serialization tests
```

---

## Repository name

```text
ltx-studio-local
```

---

# Phase 0 — Repository bootstrap

## Goal

Create the initial Git repository structure without implementing real generation.

## TODO

- [x] Create Git repository root
- [x] Add `README.md`
- [x] Add `ROADMAP.md`
- [x] Add `CONTRIBUTING.md`
- [x] Add `CHANGELOG.md`
- [x] Add `SECURITY.md`
- [x] Add `LICENSE`
- [x] Add `.gitignore`
- [x] Add `.editorconfig`
- [x] Add root `Makefile`
- [x] Add `docs/` folder
- [x] Add `scripts/` folder
- [x] Add `shared/schemas/` folder
- [x] Add `examples/` folder
- [x] Add `.github/workflows/` folder
- [x] Add `.github/ISSUE_TEMPLATE/` folder
- [x] Add pull request template

## Expected structure

```text
ltx-studio-local/
├── README.md
├── ROADMAP.md
├── CONTRIBUTING.md
├── CHANGELOG.md
├── SECURITY.md
├── LICENSE
├── AGENTS.md
├── Makefile
├── .gitignore
├── .editorconfig
├── .github/
├── app/
├── worker/
├── shared/
├── docs/
├── examples/
└── scripts/
```

## Prompt for Junie

```text
Create the initial Git repository structure for a project called LTX Studio Local.

This is a multi-language repository for a local-first AI video creation app for Apple Silicon.

Create the following root files:
- README.md
- ROADMAP.md
- CONTRIBUTING.md
- CHANGELOG.md
- SECURITY.md
- LICENSE
- .gitignore
- .editorconfig
- Makefile

Create these folders:
- app/
- worker/
- shared/schemas/
- docs/
- examples/
- scripts/
- .github/workflows/
- .github/ISSUE_TEMPLATE/

Add a pull request template and basic issue templates for bug reports, feature requests and model support requests.

Do not implement application code yet. This step is only repository bootstrap.

Make sure the README clearly explains that the project will contain a SwiftUI macOS app and a Python MLX/LTX worker.
```

---

# Phase 1 — Python worker skeleton

## Goal

Create a working Python worker with mock endpoints. This gives the Swift app something stable to talk to later.

## TODO

- [x] Create `worker/pyproject.toml`
- [x] Use Python 3.11 or newer
- [x] Add FastAPI
- [x] Add Uvicorn
- [x] Add Pydantic
- [x] Add pytest
- [x] Add ruff
- [x] Add basic package structure
- [x] Add `ltx_worker/main.py`
- [x] Add `/health` endpoint
- [x] Add `/hardware` endpoint with mocked Apple Silicon info
- [x] Add `/models` endpoint with mocked LTX model profiles
- [x] Add `/generate/text-to-video` endpoint returning a mock job
- [x] Add `/jobs/{job_id}` endpoint
- [x] Add in-memory job store
- [x] Add simulated progress
- [x] Add structured logging
- [x] Add tests for `/health`
- [x] Add tests for `/models`
- [x] Add tests for mock generation job creation
- [x] Add `scripts/run-worker.sh`
- [x] Add `scripts/test.sh`

## Worker folder structure

```text
worker/
├── pyproject.toml
├── README.md
├── ltx_worker/
│   ├── __init__.py
│   ├── main.py
│   ├── api.py
│   ├── config.py
│   ├── logging_config.py
│   ├── engine/
│   ├── jobs/
│   ├── schemas/
│   └── utils/
└── tests/
```

## Prompt for Junie

```text
Implement the Python worker skeleton for LTX Studio Local.

Requirements:

1. Use Python 3.11+.
2. Use FastAPI and Pydantic.
3. Add a clean package structure under worker/ltx_worker/.
4. Implement these endpoints:
   - GET /health
   - GET /hardware
   - GET /models
   - POST /generate/text-to-video
   - GET /jobs/{job_id}
5. The /hardware endpoint should return mocked Apple Silicon hardware information.
6. The /models endpoint should return mocked LTX model profiles:
   - LTX-2.3 Distilled
   - LTX-2.3 Dev
   - LTX-2.3 Quantized
7. The text-to-video endpoint should create a mock generation job.
8. Jobs should be stored in memory for now.
9. Add simulated job progress.
10. Add structured logging.
11. Add pytest tests for health, models and mock job creation.
12. Add scripts/run-worker.sh and scripts/test.sh.

Do not implement real MLX or LTX generation yet. Keep the worker API clean and stable so the SwiftUI app can integrate with it later.
```

---

# Phase 2 — Shared JSON schemas

## Goal

Define stable JSON contracts shared between the SwiftUI app and Python worker.

## TODO

- [x] Create `project.schema.json`
- [x] Create `scene.schema.json`
- [x] Create `continuity-element.schema.json`
- [x] Create `generation-job.schema.json`
- [x] Create `model-profile.schema.json`
- [x] Create `generation-request.schema.json`
- [x] Create `generation-response.schema.json`
- [x] Document schema purpose in `docs/project-format.md`
- [x] Add examples in `shared/examples/`

## Prompt for Junie

```text
Create shared JSON schemas for LTX Studio Local.

Add the following files under shared/schemas/:

- project.schema.json
- scene.schema.json
- continuity-element.schema.json
- generation-job.schema.json
- model-profile.schema.json
- generation-request.schema.json
- generation-response.schema.json

The schemas must support:

Project:
- id
- name
- created_at
- modified_at
- default_brand_kit_id
- aspect_ratio
- scenes
- timeline

Scene:
- id
- name
- mode
- prompt
- negative_prompt
- duration_seconds
- aspect_ratio
- resolution
- attached continuity elements
- consistency locks
- generations

Continuity element:
- id
- type
- name
- description
- prompt_block
- negative_prompt
- tags
- assets
- created_at
- modified_at

Generation job:
- id
- project_id
- scene_id
- status
- mode
- model_profile
- request
- progress
- output paths
- error information

Model profile:
- id
- name
- model_family
- version
- local_path
- memory_requirement
- quality_level
- installed
- recommended

Also create docs/project-format.md explaining the schema design and add small example JSON files under shared/examples/.
```

---

# Phase 3 — SwiftUI app shell

## Goal

Create the initial macOS SwiftUI app shell. The app does not need real generation yet.

## TODO

- [x] Create macOS SwiftUI app under `app/`
- [x] Create `LTXStudioLocalApp.swift`
- [x] Create app-level state object
- [x] Create navigation router
- [x] Add dark-mode-first layout
- [x] Add Home Dashboard screen
- [x] Add Project Studio placeholder
- [x] Add Continuity Library placeholder
- [x] Add Model Manager placeholder
- [x] Add Render Queue placeholder
- [x] Add Settings placeholder
- [x] Add mock data
- [x] Add previews where possible

## Prompt for Junie

```text
Create the initial SwiftUI macOS application shell for LTX Studio Local under app/.

The app should be a native macOS SwiftUI application.

Implement:

- AIStudioLocalApp.swift
- AppState
- AppRouter
- Main navigation layout
- Home Dashboard screen
- Project Studio placeholder screen
- Continuity Library placeholder screen
- Model Manager placeholder screen
- Render Queue placeholder screen
- Settings placeholder screen

The UI should be dark-mode-first and feel like a polished Mac creative application.

Use mock data only. Do not connect to the Python worker yet.

Keep business logic out of SwiftUI views. Use ViewModels or services where appropriate.
```

---

# Phase 4 — SwiftUI design system

## Goal

Create reusable design components so the app stays visually consistent.

## TODO

- [x] Add semantic colours
- [x] Add typography tokens
- [x] Add spacing tokens
- [x] Add reusable button styles
- [x] Add `PrimaryButton`
- [x] Add `SecondaryButton`
- [x] Add `IconButton`
- [x] Add `ElementChip`
- [x] Add `ProjectCard`
- [x] Add `SceneCard`
- [x] Add `ModelCard`
- [x] Add `ProgressCard`
- [x] Add `EmptyStateView`
- [x] Add `InspectorPanel`
- [x] Add `StatusBadge`
- [x] Replace temporary UI elements with design system components

## Prompt for Junie

```text
Create a reusable SwiftUI design system for LTX Studio Local.

Add a DesignSystem folder with:

- semantic colours
- typography definitions
- spacing constants
- reusable button components
- reusable cards
- reusable chips
- reusable inspector panels
- reusable empty states
- reusable progress cards
- reusable status badges

Create these components:

- PrimaryButton
- SecondaryButton
- IconButton
- ElementChip
- ProjectCard
- SceneCard
- ModelCard
- ProgressCard
- EmptyStateView
- InspectorPanel
- StatusBadge

Refactor the existing Home Dashboard and placeholder screens to use these components.

The UI should remain simple, clear and polished. Avoid hard-coded colours and spacing inside feature views.
```

---

# Phase 5 — Domain models in Swift

## Goal

Create the Swift domain models used by the app.

## TODO

- [x] Add `Project.swift`
- [x] Add `Scene.swift`
- [x] Add `GenerationJob.swift`
- [x] Add `ContinuityElement.swift`
- [x] Add `CharacterElement.swift`
- [x] Add `LocationElement.swift`
- [x] Add `StyleElement.swift`
- [x] Add `CameraPreset.swift`
- [x] Add `AudioIdentity.swift`
- [x] Add `BrandKit.swift`
- [x] Add `PromptBlock.swift`
- [x] Add `LoraReference.swift`
- [x] Add `ExportTemplate.swift`
- [x] Add `ModelProfile.swift`
- [x] Add Codable support
- [x] Add sample fixtures
- [x] Add unit tests for encoding/decoding

## Prompt for Junie

```text
Implement the Swift domain models for LTX Studio Local.

Create models under app/LTXStudioLocal/Domain/.

Required models:

- Project
- Scene
- GenerationJob
- ContinuityElement
- CharacterElement
- LocationElement
- StyleElement
- CameraPreset
- AudioIdentity
- BrandKit
- PromptBlock
- LoraReference
- ExportTemplate
- ModelProfile

Requirements:

1. All models must conform to Codable where appropriate.
2. Use stable string IDs.
3. Use created_at and modified_at dates where appropriate.
4. Support attached continuity elements on scenes.
5. Support consistency locks on scenes.
6. Add mock fixtures for previews.
7. Add unit tests for JSON encoding and decoding.

Keep the model structure aligned with the JSON schemas in shared/schemas/.
```

---

# Phase 6 — Project storage

## Goal

Implement Git-friendly project folder persistence.

## TODO

- [x] Create `ProjectStore` protocol
- [x] Create `FileProjectStore`
- [x] Save project as folder
- [x] Save `project.json`
- [x] Save scenes under `scenes/`
- [x] Save prompts as Markdown
- [x] Save generation metadata
- [x] Load project from folder
- [x] Validate missing files gracefully
- [x] Add project README generation
- [x] Add tests for save/load

## Project folder example

```text
ExampleProject.ltxproject/
├── project.json
├── timeline.json
├── scenes/
│   └── scene-001/
│       ├── scene.json
│       ├── prompt.md
│       └── generations/
├── assets/
├── exports/
└── README.md
```

## Prompt for Junie

```text
Implement Git-friendly project storage for LTX Studio Local.

Create a ProjectStore protocol and FileProjectStore implementation.

A project must be saved as a readable folder with this structure:

ProjectName.ltxproject/
- project.json
- timeline.json
- scenes/
- assets/
- exports/
- README.md

Each scene should be saved under scenes/scene-id/ with:

- scene.json
- prompt.md
- generations/
- references/

Requirements:

1. Save and load projects using Codable JSON.
2. Save scene prompts as Markdown for easy Git diffing.
3. Generate a README.md inside each project folder.
4. Handle missing optional folders gracefully.
5. Add tests for save/load.
6. Document the format in docs/project-format.md.

Do not store large model files inside projects.
```

---

# Phase 7 — Home Dashboard UX

## Goal

Make the first screen friendly and useful.

## TODO

- [x] Add welcome headline
- [x] Add create action cards
- [x] Add recent projects section
- [x] Add system status card
- [x] Add installed model card
- [x] Add render queue summary
- [x] Add local privacy message
- [x] Add empty states
- [ ] Add keyboard shortcuts where appropriate

## Prompt for Junie

```text
Improve the Home Dashboard user experience.

The Home Dashboard should feel like a polished creative Mac application.

Add these sections:

1. Welcome area with the text:
   "What do you want to make today?"

2. Create action cards:
   - Text to Video
   - Animate Image
   - Audio to Video
   - Retake Existing Video
   - Multi-Scene Story
   - Manage Reusable Elements
   - Manage Local Models

3. Recent Projects section.

4. System Status card showing mocked Mac hardware status.

5. Installed Model card showing mocked LTX model readiness.

6. Render Queue summary.

7. Local privacy message:
   "Local Mode: Your prompts, images, audio and generated videos stay on this Mac."

Use the existing design system components. Keep the UI clean and not crowded.
```

---

# Phase 8 — Project Studio screen

## Goal

Create the main project workspace UI.

## TODO

- [x] Create three-pane layout
- [x] Add left project sidebar
- [x] Add scene list
- [x] Add asset navigation placeholders
- [x] Add centre preview canvas
- [x] Add right scene inspector
- [x] Add bottom timeline placeholder
- [x] Add scene selection
- [x] Add add/delete/rename scene actions
- [x] Add attached element chips
- [x] Add generate button placeholder

## Prompt for Junie

```text
Implement the first real Project Studio screen.

The layout should have:

- Left sidebar with scenes and project sections
- Centre preview canvas
- Right scene inspector
- Bottom timeline placeholder

Features:

1. Display scenes from the selected project.
2. Allow selecting a scene.
3. Allow adding a scene.
4. Allow deleting a scene.
5. Allow renaming a scene.
6. Show the scene prompt in the inspector.
7. Show attached continuity elements as chips.
8. Show consistency locks in the inspector.
9. Add a visible "Generate Scene" button, but it may still be mock-only.
10. Add a bottom timeline placeholder showing scene clips.

The UI should be easy and visually clear. Do not expose advanced generation settings yet.
```

---

# Phase 9 — Continuity Library v1

## Goal

Create reusable elements across projects.

## TODO

- [x] Create `ContinuityStore` protocol
- [x] Create file-based global continuity store
- [x] Add category sidebar
- [x] Add element list
- [x] Add element detail editor
- [x] Add create element action
- [x] Add edit element action
- [x] Add delete element action
- [x] Add search
- [x] Add tag filtering
- [x] Add default sample elements
- [ ] Add import/export library folder
- [x] Add tests for continuity storage

## Prompt for Junie

```text
Implement Continuity Library v1.

The Continuity Library is a global reusable element system used across projects.

Element types:

- Character
- Location
- Visual Style
- Camera Preset
- Audio Identity
- Brand Kit
- Prompt Block
- LoRA Reference
- Export Template

Requirements:

1. Add a ContinuityStore protocol.
2. Add a file-based continuity store.
3. Store elements as readable JSON files.
4. Add category navigation.
5. Add list/detail editing.
6. Add create/edit/delete actions.
7. Add search.
8. Add tag filtering.
9. Add helpful empty states.
10. Add default sample elements.
11. Add tests for storage.
12. Document the library in docs/continuity-library.md.

The UI must be simple and polished. The user should understand that these elements can be reused across many projects.
```

---

# Phase 10 — Attach continuity elements to scenes

## Goal

Allow users to attach reusable elements to scenes.

## TODO

- [x] Add “Add reusable element” button in Scene Inspector
- [x] Add element picker sheet
- [x] Filter by element type
- [x] Attach selected element to scene
- [x] Remove attached element
- [x] Show attached elements as chips
- [x] Click chip to open element detail
- [x] Add consistency lock UI
- [x] Persist attachments in project folder

## Prompt for Junie

```text
Integrate the Continuity Library with Project Studio.

In the Scene Inspector, add an "Add reusable element" action.

When clicked, show an element picker that allows the user to select from the global Continuity Library.

Requirements:

1. Filter elements by type.
2. Allow attaching characters, locations, styles, camera presets, audio identities, brand kits and prompt blocks to a scene.
3. Show attached elements as chips.
4. Allow removing an attached element from a scene.
5. Clicking a chip should open the element details.
6. Add consistency lock checkboxes:
   - character identity
   - location
   - style
   - brand
   - audio identity
   - seed
7. Persist all attachments and locks in the scene JSON.

Keep the interaction simple and obvious.
```

---

# Phase 11 — Prompt Composer

## Goal

Compose final generation prompts from scene prompts and reusable elements.

## TODO

- [x] Create `PromptComposer` service
- [x] Combine scene prompt with element prompt blocks
- [x] Combine negative prompts
- [x] Respect element order
- [x] Include camera and audio instructions
- [x] Add “View Composed Prompt” UI
- [x] Add copy button
- [x] Add tests for composition
- [x] Document prompt composition

## Prompt for Junie

```text
Implement a PromptComposer service.

The PromptComposer builds the final prompt sent to the generation worker.

Inputs:

- Scene prompt
- Scene negative prompt
- Attached character prompt blocks
- Attached location prompt blocks
- Attached style prompt blocks
- Attached camera prompt blocks
- Attached audio prompt blocks
- Attached brand prompt blocks
- Attached generic prompt blocks
- Consistency locks

Outputs:

- composed_prompt
- composed_negative_prompt
- metadata explaining which elements were included

Requirements:

1. Add unit tests for prompt composition.
2. Add a "View Composed Prompt" button in the Scene Inspector.
3. Show the composed prompt in a readable sheet.
4. Add a copy-to-clipboard button.
5. Keep the composed prompt human-readable.
6. Do not hide what is sent to the generation worker.

This feature is important for trust and reproducibility.
```

---

# Phase 12 — Model Manager v1

## Goal

Create a UI for local model awareness and future model downloads.

## TODO

- [x] Add model profile list
- [x] Show installed/not installed status
- [x] Show model purpose
- [x] Show memory requirement
- [x] Show recommended badge
- [x] Add model detail screen
- [x] Add install button placeholder
- [x] Add remove button placeholder
- [x] Add validate model placeholder
- [ ] Add hardware compatibility warning
- [x] Connect to mock worker `/models`

## Prompt for Junie

```text
Implement Model Manager v1.

The Model Manager should show available and installed LTX model profiles.

Use the worker /models endpoint if available. If the worker is not running, fall back to mock data with a clear offline state.

Show these model profiles:

- LTX-2.3 Distilled
- LTX-2.3 Dev
- LTX-2.3 Quantized
- Spatial Upscaler
- Temporal Upscaler

For each model, show:

- name
- purpose
- installed status
- memory requirement
- quality level
- recommended status
- local path if installed

Add placeholder buttons for:

- Install
- Remove
- Validate

Do not implement real model downloads yet.
```

---

# Phase 13 — Hardware Profiler v1

## Goal

Detect or mock Mac hardware and recommend safe defaults.

## TODO

- [x] Create `HardwareProfiler` protocol
- [x] Add mock implementation
- [x] Add real basic implementation where safe
- [x] Detect Apple Silicon if possible
- [x] Detect memory if possible
- [x] Show hardware status in Home Dashboard
- [x] Show recommendations in Model Manager
- [x] Add graceful fallback

## Prompt for Junie

```text
Implement Hardware Profiler v1.

Create a HardwareProfiler service that can provide:

- Mac model name if available
- Apple Silicon status
- total memory
- recommended generation profile
- local mode readiness

Use safe native macOS APIs where practical. If exact detection is not available, return an unknown state instead of crashing.

Show the hardware profile on:

- Home Dashboard
- Model Manager

Recommended profiles:

- 16 GB: limited / small quantized clips only
- 32 GB: minimum realistic local generation
- 64 GB: good local creator experience
- 96 GB or more: high-quality local workflows

Do not block the UI while checking hardware.
```

---

# Phase 14 — Swift app to worker integration ✓

## Goal

Connect the SwiftUI app to the Python worker.

## TODO

- [✓] Create `GenerationClient` protocol
- [✓] Create HTTP implementation
- [✓] Add worker health check
- [✓] Add model fetch
- [✓] Add text-to-video mock job submission
- [✓] Add job polling
- [✓] Add progress display
- [✓] Add cancel placeholder
- [✓] Show helpful error when worker unavailable

## Prompt for Junie

```text
Connect the SwiftUI app to the Python worker.

Create a GenerationClient service with an HTTP implementation.

Implement:

- health check against GET /health
- fetch model profiles from GET /models
- submit mock text-to-video job to POST /generate/text-to-video
- poll job status from GET /jobs/{job_id}
- show progress in Render Queue
- show errors when the worker is unavailable

In Project Studio:

1. When the user clicks Generate Scene, compose the prompt using PromptComposer.
2. Submit the composed prompt to the worker.
3. Create a GenerationJob in the app state.
4. Show progress.
5. When complete, attach the mock output to the scene.

Do not implement real LTX generation yet.
```

---

# Phase 15 — Render Queue UX ✓

## Goal

Make generation progress clear and trustworthy.

## TODO

- [✓] Create render queue screen
- [✓] Show active jobs
- [✓] Show completed jobs
- [✓] Show failed jobs
- [✓] Show stage and percentage
- [✓] Add cancel button
- [✓] Add retry button for failed jobs
- [✓] Add open scene button
- [✓] Add clear completed button
- [✓] Add helpful failure messages

## Prompt for Junie

```text
Implement Render Queue UX.

The Render Queue should show all generation jobs clearly.

Each job card should show:

- scene name
- generation mode
- model profile
- status
- current stage
- progress percentage
- started time
- completed time if done
- error message if failed

Actions:

- cancel running job
- retry failed job
- open related scene
- clear completed jobs

Use ProgressCard and StatusBadge from the design system.

The user must always understand what the app is doing.
```

---

# Phase 16 — Generation history ✓

## Goal

Track generated versions per scene.

## TODO

- [✓] Add generation list to scene
- [✓] Add generation metadata model
- [✓] Add generation cards
- [✓] Show preview thumbnail placeholder
- [✓] Show prompt used
- [✓] Show seed
- [✓] Show model
- [✓] Show creation date
- [✓] Add use version action
- [✓] Add delete version action
- [✓] Persist history

## Prompt for Junie

```text
Add generation history per scene.

Each scene should keep a list of generated versions.

For each generation, store:

- id
- output path
- preview image path
- composed prompt
- negative prompt
- model profile
- seed
- resolution
- duration
- created_at
- metadata JSON path

In the Scene Inspector or a dedicated History panel, show generation versions as cards.

Actions:

- use this version
- view prompt
- delete version
- regenerate from same settings

For now, use mock output paths if real video does not exist.
```

---

# Phase 17 — Basic timeline

## Goal

Create a simple scene-based timeline.

## TODO

- [x] Add timeline data model
- [x] Add timeline clip model
- [x] Add scene clips to timeline
- [x] Show clips visually
- [x] Allow reorder
- [x] Allow select clip
- [x] Allow remove clip
- [x] Allow duplicate clip
- [x] Add basic duration display
- [x] Persist timeline

## Prompt for Junie

```text
Implement a basic scene-based timeline.

The timeline should appear at the bottom of Project Studio.

Features:

1. Show each scene as a timeline clip.
2. Show scene name and duration.
3. Allow selecting a clip.
4. Allow reordering clips.
5. Allow removing clips from the timeline.
6. Allow duplicating clips.
7. Persist timeline data in timeline.json.

Do not implement advanced video editing yet. Keep the timeline simple and reliable.
```

---

# Phase 18 — Export service v1

## Goal

Create export structure and mock export workflow.

## TODO

- [x] Create `ExportService` protocol ✓
- [x] Create mock export implementation ✓
- [x] Add export presets ✓
- [x] Add MP4 export option placeholder ✓
- [x] Add ProRes export option placeholder ✓
- [x] Add LinkedIn 4:5 preset ✓
- [x] Add YouTube 16:9 preset ✓
- [x] Add Shorts/Reels 9:16 preset ✓
- [x] Save export metadata ✓
- [x] Add export dialog ✓

## Prompt for Junie

```text
Implement Export Service v1 with mock export support.

Create export presets:

- LinkedIn 4:5 MP4
- YouTube 16:9 MP4
- Shorts/Reels 9:16 MP4
- ProRes master placeholder

Add an Export dialog in Project Studio.

The mock export should:

1. Validate that the timeline has clips.
2. Create an exports/ folder in the project.
3. Write an export metadata JSON file.
4. Show a completed export entry in the UI.

Do not implement real video encoding yet.
```

---

# Phase 19 — Brand overlays v1

## Goal

Extend Brand Kit support for deterministic overlays. The AI model should not be trusted to render accurate logos or text. Brand elements must be applied during export.

## TODO

- [✓] Extend `BrandKit` model with overlay metadata
- [✓] Add Brand Kit editor UI in Continuity Library
- [✓] Add simple preview panel for brand overlays
- [✓] Implement actual video overlay rendering in `ExportService` (Future Phase)
- [✓] Add logo asset management (pick file)
- [✓] Support custom font selection for overlays

## Prompt for Junie (Updated)

Extend Brand Kit support for deterministic overlays.

The AI model should not be trusted to render accurate logos or text. Brand elements must be applied during export.

Extend BrandKit with:

- logo asset path
- brand colours
- title card settings
- lower-third settings
- watermark settings
- subtitle style settings
- intro card text
- outro card text
- CTA templates

Add a Brand Kit editor UI in the Continuity Library.

Add a simple preview panel showing how the brand overlay may look.

For now, only store overlay metadata. Real video overlay rendering will be implemented later.

---

# Phase 20 — Prompt improvement helper v1

## Goal

Add UX for improving rough prompts.

## TODO

- [x] Add “Improve Prompt” button
- [x] Add local rule-based prompt enhancer first
- [x] Add cinematic structure
- [x] Add camera instruction support
- [x] Add audio cue support
- [x] Show before/after
- [x] Allow accept/reject
- [x] Add tests for helper

## Prompt for Junie

```text
Implement Prompt Improvement Helper v1.

Add an "Improve Prompt" button next to scene prompts.

For now, implement a local rule-based helper. Do not call an external LLM.

The helper should turn short prompts into richer video prompts by adding structure:

- subject
- action
- environment
- camera movement
- lighting
- mood
- audio cues

Show a before/after comparison and allow the user to accept or reject the improved prompt.

Keep the generated text editable.
```

---

# Phase 21 — Error handling and friendly messages

## Goal

Make failures useful to users.

## TODO

- [x] Define error model
- [x] Add user-facing error messages
- [x] Add technical details disclosure
- [x] Add worker unavailable message
- [x] Add missing model message
- [x] Add insufficient memory message
- [x] Add generation failed message
- [x] Add retry actions
- [x] Add tests for error mapping

## Prompt for Junie

```text
Improve error handling across the app.

Create a user-facing error model that separates:

- user message
- technical details
- suggested actions
- retry availability

Add friendly messages for:

- worker unavailable
- model not installed
- unsupported Mac
- insufficient memory
- generation failed
- export failed
- project load failed
- project save failed

Bad message:
"Generation failed."

Good message:
"This generation needs more memory than your Mac currently has available. Try using Fast Draft mode, lowering the resolution, or reducing the duration."

Add a disclosure area for technical details so advanced users can inspect logs.
```

---

# Phase 22 — Documentation pass

## Goal

Keep docs aligned with implementation.

## TODO

- [x] Update README
- [x] Update ROADMAP
- [x] Update architecture doc
- [x] Update UX doc
- [x] Update continuity doc
- [x] Update model manager doc
- [x] Update development setup
- [x] Add screenshots placeholders
- [x] Add troubleshooting section

## Prompt for Junie

```text
Do a documentation pass for the current state of LTX Studio Local.

Update:

- README.md
- ROADMAP.md
- docs/architecture.md
- docs/user-experience.md
- docs/continuity-library.md
- docs/model-manager.md
- docs/development-setup.md
- docs/project-format.md

The documentation should clearly explain:

- project goal
- current status
- how to run the worker
- how to open the SwiftUI app
- project folder format
- Continuity Library concept
- mock generation flow
- planned real MLX/LTX integration

Do not claim real generation works unless it actually does.
```

---

# Phase 23 — CI and quality gates

## Goal

Add basic automation for a Git-maintained project.

## TODO

- [x] Add GitHub Action for Python tests
- [x] Add GitHub Action for Python lint
- [x] Add GitHub Action for schema validation if practical
- [x] Add Swift lint workflow if practical
- [x] Add PR template checklist
- [x] Add issue labels doc
- [x] Add release checklist

## Prompt for Junie

```text
Add basic CI quality gates for LTX Studio Local.

Implement GitHub Actions for:

1. Python worker linting with ruff.
2. Python worker tests with pytest.
3. JSON schema validation if practical.
4. Swift linting if available in the project setup.

Update the pull request template with a checklist:

- tests pass
- lint passes
- documentation updated
- UI screenshots added for GUI changes
- no large model files committed
- no generated videos committed unless intentionally using Git LFS

Also add a docs/release-checklist.md file.
```

---

# Phase 24 — Real MLX/LTX integration preparation

## Goal

Prepare the architecture for real generation without implementing it all at once.

## TODO

- [x] Add `GenerationEngine` abstraction
- [x] Add `MockGenerationEngine`
- [x] Add `LTXGenerationEngine` placeholder
- [x] Add model loader abstraction
- [x] Add LoRA loader abstraction
- [x] Add media encoder abstraction
- [x] Add progress callback mechanism
- [x] Add cancellation token support
- [x] Add output folder management

## Prompt for Junie

```text
Prepare the Python worker architecture for real MLX/LTX generation.

Do not implement full real generation yet.

Add these abstractions:

- GenerationEngine
- MockGenerationEngine
- LTXGenerationEngine placeholder
- ModelLoader
- LoraLoader
- MediaEncoder
- OutputManager

Requirements:

1. The existing API endpoints must remain stable.
2. MockGenerationEngine should continue to work.
3. LTXGenerationEngine may raise a clear "not implemented" error for now.
4. Add progress callback support.
5. Add cancellation token support.
6. Add output folder management.
7. Add tests proving mock generation still works through the abstraction.

The goal is to make the later real MLX integration safe and isolated.
```

---

# Phase 25 — Real text-to-video generation

## Goal

Integrate the first real LTX/MLX text-to-video path.

## Important caution

Only start this phase after the mock app workflow is stable.

## TODO

- [x] Choose MLX/LTX backend implementation
- [x] Document install requirements
- [x] Add model path configuration
- [x] Load model safely
- [x] Validate model exists
- [x] Validate hardware memory
- [x] Implement text-to-video generation
- [x] Save output video
- [x] Save preview frame
- [x] Save metadata
- [x] Stream progress
- [x] Handle cancellation
- [x] Add clear errors
- [x] Add manual test script

## Prompt for Junie

```text
Implement the first real text-to-video generation path in the Python worker using the selected MLX/LTX backend.

Requirements:

1. Keep the public worker API stable.
2. Add configuration for local model paths.
3. Validate that required model files exist before generation.
4. Validate that the current Mac appears compatible.
5. Implement text-to-video generation behind LTXGenerationEngine.
6. Save output video to the project generation folder.
7. Save preview image if possible.
8. Save metadata.json containing:
   - prompt
   - negative prompt
   - model profile
   - seed
   - duration
   - resolution
   - generation settings
   - generation time
9. Stream progress updates.
10. Support cancellation if possible.
11. Return actionable errors for missing models, memory problems and encoding failures.
12. Add a manual test script for local generation.

Do not break mock generation. Keep MockGenerationEngine available for development and CI.
```

---

# Phase 26 — Image-to-video generation

## Goal

Add image animation workflow.

## TODO

- [x] Add image input to scene model
- [x] Add drag/drop image area
- [x] Add image preview
- [x] Add image-to-video request schema
- [x] Add worker endpoint if not present
- [x] Add mock image-to-video job
- [ ] Add real image-to-video behind engine later
- [x] Save input image reference
- [x] Save metadata

## Prompt for Junie

```text
Add image-to-video support to LTX Studio Local.

SwiftUI app requirements:

1. Allow a scene to use image-to-video mode.
2. Add drag-and-drop image input.
3. Show image preview.
4. Store the image reference in the scene.
5. Submit an image-to-video generation request to the worker.

Worker requirements:

1. Add POST /generate/image-to-video if it does not already exist.
2. Support mock image-to-video jobs.
3. Add schema validation for input image path and prompt.
4. Save metadata.

Do not implement real image-to-video unless the real generation engine is already stable. Keep this phase safe and incremental.
```

---

# Phase 27 — Retake workflow placeholder

## Goal

Prepare UI and API for future retake support.

## TODO

- [ ] Add retake mode to scene/generation schema
- [ ] Add timeline range selection placeholder
- [ ] Add retake prompt field
- [ ] Add lock controls
- [ ] Add worker endpoint placeholder
- [ ] Add mock retake job
- [ ] Add documentation

## Prompt for Junie

```text
Add a placeholder Retake workflow.

Retake means selecting part of a generated clip and regenerating only that section.

For now, implement UI and mock worker support only.

Requirements:

1. Add retake generation mode to shared schemas.
2. Add a Retake button in the timeline/preview area.
3. Allow selecting a start and end time range using simple numeric fields for now.
4. Allow entering a retake prompt.
5. Reuse consistency locks from the scene.
6. Add POST /generate/retake endpoint to the worker.
7. Return a mock retake job.
8. Document that real retake generation is planned later.
```

---

# Phase 28 — Audio identity and audio workflow placeholder

## Goal

Prepare audio-led workflows.

## TODO

- [ ] Add audio identity element editor
- [ ] Add audio input to scene
- [ ] Add generated audio toggle
- [ ] Add mute toggle
- [ ] Add voiceover placeholder
- [ ] Add audio-to-video endpoint placeholder
- [ ] Add mock audio-to-video job

## Prompt for Junie

```text
Add audio workflow placeholders.

The app should support future LTX audio-video generation, but this phase may remain mock-only.

Implement:

1. Audio Identity editor in the Continuity Library.
2. Scene audio options:
   - generate matching audio
   - mute generated audio
   - use imported audio
   - voiceover placeholder
3. Add audio input file reference to scenes.
4. Add POST /generate/audio-to-video endpoint to the worker.
5. Return a mock audio-to-video job.
6. Show audio identity chips in the Scene Inspector.

Keep the UI simple. Do not implement full audio mixing yet.
```

---

# Phase 29 — Local privacy and settings

## Goal

Make local-first behaviour explicit and configurable.

## TODO

- [ ] Add settings screen sections
- [ ] Add local mode status
- [ ] Add worker URL setting
- [ ] Add project storage location setting
- [ ] Add continuity library location setting
- [ ] Add model folder setting
- [ ] Add telemetry disabled statement
- [ ] Add cloud fallback placeholder disabled by default

## Prompt for Junie

```text
Implement Settings v1.

Add settings for:

- worker URL
- project storage location
- continuity library location
- model folder location
- default export folder
- local mode status
- cloud fallback placeholder, disabled by default

The settings screen should clearly state:

"Local Mode: prompts, source assets and generated media stay on this Mac unless you explicitly enable an external service."

Do not add telemetry. If telemetry is ever added later, it must be opt-in.
```

---

# Phase 30 — Git hygiene for large files

## Goal

Prevent accidental commits of models and generated videos.

## TODO

- [ ] Update `.gitignore`
- [ ] Add `.gitattributes` for Git LFS examples
- [ ] Document model storage
- [ ] Document generated media storage
- [ ] Add pre-commit guidance
- [ ] Add warning in README

## Prompt for Junie

```text
Improve Git hygiene for large files.

Update .gitignore to prevent accidental commits of:

- model files
- safetensors files
- checkpoints
- generated videos
- generated audio
- cache folders
- temporary render folders

Add .gitattributes examples for Git LFS:

- mp4
- mov
- wav
- png
- jpg

Update README and docs/development-setup.md explaining:

1. Do not commit models.
2. Do not commit generated videos unless intentionally using Git LFS.
3. Keep project metadata Git-friendly.
4. Store large local assets outside the repository when possible.
```

---

# Phase 31 — UX polish pass

## Goal

Make the app feel easy and professional.

## TODO

- [ ] Review empty states
- [ ] Review labels
- [ ] Review button hierarchy
- [ ] Review spacing
- [ ] Review sidebar clarity
- [ ] Review inspector layout
- [ ] Review onboarding flow
- [ ] Add tooltips
- [ ] Add keyboard shortcuts
- [ ] Add loading states
- [ ] Add disabled states
- [ ] Add accessibility labels

## Prompt for Junie

```text
Perform a UX polish pass across the SwiftUI app.

Focus on making the app easy for non-technical creative users.

Review and improve:

- empty states
- button labels
- spacing
- visual hierarchy
- sidebar navigation
- inspector layout
- loading states
- disabled states
- error messages
- tooltips
- accessibility labels

Important rule:
The default UI must not expose technical generation parameters such as seed, steps, guidance scale or quantization unless the user opens Advanced Settings.

Make the app feel like a Mac creative application, not a developer tool.
```

---

# Phase 32 — Advanced settings panel

## Goal

Expose expert controls without overwhelming normal users.

## TODO

- [ ] Add collapsed Advanced Settings panel
- [ ] Add seed control
- [ ] Add steps control
- [ ] Add guidance control
- [ ] Add FPS control
- [ ] Add frame count control
- [ ] Add model profile selector
- [ ] Add LoRA weight placeholder
- [ ] Add upscaler selector placeholder
- [ ] Add reset to recommended defaults

## Prompt for Junie

```text
Add an Advanced Settings panel to the Scene Inspector.

The panel must be collapsed by default.

Advanced settings:

- seed
- inference steps
- guidance scale
- FPS
- frame count
- model profile
- LoRA weights placeholder
- upscaler placeholder
- quantization mode placeholder

Add a "Reset to Recommended Defaults" button.

Important UX rule:
Beginners should never need to open this panel to create a video.
```

---

# Phase 33 — Template system v1

## Goal

Create project templates for repeatable workflows.

## TODO

- [ ] Add template model
- [ ] Add default templates
- [ ] Add LinkedIn SRE Explainer template
- [ ] Add YouTube Tech Intro template
- [ ] Add Book Promo template
- [ ] Add create project from template
- [ ] Add template preview
- [ ] Persist selected template metadata

## Prompt for Junie

```text
Implement Project Templates v1.

Templates allow users to create repeatable project structures.

Default templates:

1. LinkedIn SRE Explainer
   - aspect ratio 4:5
   - structure: hook, problem, example, insight, question

2. YouTube Tech Intro
   - aspect ratio 16:9
   - structure: intro, problem, main idea, closing

3. Book Promo Video
   - aspect ratio 9:16
   - structure: hook, book value, quote, CTA

Requirements:

- Add template model
- Add template selection screen during new project creation
- Create scenes from template
- Attach default brand kit if selected
- Allow user to edit everything after creation
```

---

# Phase 34 — Import/export Continuity Library

## Goal

Allow sharing reusable creative systems across machines/repos.

## TODO

- [ ] Export library as folder
- [ ] Export selected elements
- [ ] Import library folder
- [ ] Detect duplicate IDs
- [ ] Offer merge/replace/skip
- [ ] Validate JSON
- [ ] Add import result summary

## Prompt for Junie

```text
Implement import/export for the Continuity Library.

Requirements:

1. Export the entire continuity library as a folder of JSON files.
2. Export selected elements only.
3. Import a continuity library folder.
4. Validate imported JSON.
5. Detect duplicate element IDs.
6. Offer conflict handling:
   - skip
   - replace
   - create copy
7. Show an import summary.

This allows users to reuse the same characters, styles and brand kits across different machines or Git repositories.
```

---

# Phase 35 — Final MVP release preparation

## Goal

Prepare the first usable MVP release.

## TODO

- [ ] Verify app shell works
- [ ] Verify worker starts
- [ ] Verify mock generation works
- [ ] Verify project save/load works
- [ ] Verify continuity elements work
- [ ] Verify prompt composition works
- [ ] Verify render queue works
- [ ] Verify model manager mock works
- [ ] Update README
- [ ] Update CHANGELOG
- [ ] Add release notes
- [ ] Tag version `v0.1.0`

## Prompt for Junie

```text
Prepare the v0.1.0 MVP release for LTX Studio Local.

Verify:

- SwiftUI app opens
- Home Dashboard works
- Project Studio works with mock data
- Project save/load works
- Continuity Library works
- Elements can be attached to scenes
- PromptComposer works
- Python worker starts
- Mock text-to-video generation works
- Render Queue shows progress
- Model Manager shows model profiles
- Documentation is up to date

Update:

- README.md
- CHANGELOG.md
- ROADMAP.md
- docs/development-setup.md

Create release notes for v0.1.0.

Do not claim real LTX/MLX generation works unless it has actually been implemented and tested.
```

---

# Recommended implementation order summary

Use this order:

```text
0. Repository bootstrap
1. Python worker skeleton
2. Shared schemas
3. SwiftUI app shell
4. Design system
5. Swift domain models
6. Project storage
7. Home Dashboard UX
8. Project Studio
9. Continuity Library
10. Attach elements to scenes
11. Prompt Composer
12. Model Manager
13. Hardware Profiler
14. App-to-worker integration
15. Render Queue
16. Generation history
17. Basic timeline
18. Export service mock
19. Brand overlays metadata
20. Prompt improvement helper
21. Friendly error handling
22. Documentation pass
23. CI quality gates
24. Real generation architecture preparation
25. Real text-to-video generation
26. Image-to-video generation
27. Retake workflow
28. Audio workflow
29. Settings and privacy
30. Git hygiene
31. UX polish
32. Advanced settings
33. Templates
34. Continuity import/export
35. MVP release
```

---

# Definition of done for every phase

A phase is done only when:

- [ ] Code compiles or scripts run successfully
- [ ] Tests pass where tests exist
- [ ] No obvious UI regression
- [ ] Documentation is updated if behaviour changed
- [ ] No large generated files are committed
- [ ] No model files are committed
- [ ] Git status is clean after commit
- [ ] Commit message uses conventional commit format

---

# Final instruction for Junie

Build this project like a product, not like a demo.

The MLX/LTX model integration is important, but the real value of this application is the **user experience**, the **Continuity Library**, the **project workflow**, and the ability to create consistent AI video projects locally on a Mac.

The application must stay easy for beginners while still giving advanced users control when they need it.
