# Project Format and Shared Schemas

This document describes the project structure and the shared JSON schemas used by LTX Studio Local to ensure consistency between the macOS SwiftUI application and the Python generation worker.

## Project Structure

Projects are stored as folders with the `.ltxproject` extension. This format is Git-friendly and allows for easy organization of assets and generations.

```text
MyProject.ltxproject/
│
├── project.json            # Main project metadata and settings
├── timeline.json           # Timeline structure and clip ordering
├── scenes/                 # All scenes in the project
│   ├── scene-001/
│   │   ├── scene.json      # Scene settings and prompt
│   │   ├── prompt.md       # Human-readable prompt (optional)
│   │   ├── generations/    # Output of generation jobs
│   │   │   ├── gen-001/
│   │   │   │   ├── output.mp4
│   │   │   │   ├── preview.jpg
│   │   │   │   ├── metadata.json
│   │   │   │   └── composed-prompt.md
│   │   └── references/     # Input images/audio for the scene
│   └── ...
├── assets/                 # Shared project assets
│   ├── images/
│   ├── audio/
│   └── video/
└── exports/                # Final rendered outputs
```

## Shared Schemas

The following JSON schemas define the contracts between the app and the worker. They are located in `shared/schemas/`.

### 1. Project (`project.schema.json`)
The root metadata for a project. Includes IDs, timestamps, and references to scenes.

### 2. Scene (`scene.schema.json`)
Defines the creative parameters for a single clip, including prompts, duration, attached continuity elements, and consistency locks.

### 3. Continuity Element (`continuity-element.schema.json`)
Reusable creative blocks like characters, locations, or visual styles. They can be attached to multiple scenes to maintain consistency.

### 4. Generation Job (`generation-job.schema.json`)
Tracks the status and progress of a background generation task in the worker.

### 5. Model Profile (`model-profile.schema.json`)
Describes a local ML model, including its performance characteristics and memory requirements.

### 6. Generation Request (`generation-request.schema.json`)
The payload sent from the App to the Worker to initiate a new generation.

### 7. Generation Response (`generation-response.schema.json`)
The immediate acknowledgement from the Worker when a job is successfully queued.

## Implementation Details

- **IDs:** All major entities use UUIDs for unique identification.
- **Timestamps:** ISO 8601 format is used for all date-time fields.
- **Local-First:** All paths are relative to the project root or local filesystem, ensuring projects remain portable.
