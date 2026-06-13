# Project Format and Shared Schemas

This document describes the project structure and the shared JSON schemas used by LTX Studio Local to ensure consistency between the macOS SwiftUI application and the Python generation worker.

## Project Structure

Projects are stored as folders with the `.ltxproject` extension. This format is Git-friendly and allows for easy organization of assets and generations.

```text
MyProject.ltxproject/
│
├── project.json            # Main project metadata and settings
├── timeline.json           # Timeline structure and clip ordering
├── README.md               # Human-readable project summary
├── scenes/                 # All scenes in the project
│   ├── <scene-id>/
│   │   ├── scene.json      # Scene settings and metadata
│   │   ├── prompt.md       # Human-readable prompt for Git diffing
│   │   ├── generations/    # Output of generation jobs
│   │   │   ├── <gen-id>/
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

### File Details

- **project.json**: Contains the core `Project` model, including name, IDs, and metadata.
- **timeline.json**: Contains the `Timeline` model, defining how scenes are ordered and their durations.
- **README.md**: Automatically generated summary of the project for easy viewing in Git platforms.
- **scenes/<id>/scene.json**: The `Scene` model data.
- **scenes/<id>/prompt.md**: The scene's prompt stored as a plain text file, making it easy to see changes in Git.
- **assets/**: Organized folders for reusable media assets used within the project.
- **exports/**: The destination for final rendered videos.

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

## Creating a Project

To create a new project:
1. Open the LTX Studio Local application.
2. On the **Home Dashboard**, click **New Project**.
3. Enter a project name and select a storage location (defaults to `~/Documents/LTX Studio Local/Projects/`).
4. Click **Create Project**.

The app will create the `.ltxproject` folder structure and a default first scene.

## Mock Generation Flow

In the current version (v0.1.0), the generation process can be mocked to validate the end-to-end architecture:

1. **App** sends a `GenerationRequest` to the **Worker**'s `/generate/text-to-video` endpoint.
2. **Worker** validates the request against `generation-request.schema.json`.
3. **Worker** creates a `GenerationJob`, saves it to the `JobStore`, and returns a `JobStatus` response.
4. **App** begins polling the Worker's `/jobs/{id}` endpoint or listens for events.
5. **Worker** advances the job state through stages (real or mock depending on `ENGINE_TYPE`).
6. **Worker** generates an MP4 file and a `metadata.json` in the scene's generation folder.
7. **App** detects the `completed` status and refreshes the Scene UI to show the new generation.

## Implementation Details

- **IDs:** All major entities use UUIDs for unique identification.
- **Timestamps:** ISO 8601 format is used for all date-time fields.
- **Local-First:** All paths are relative to the project root or local filesystem, ensuring projects remain portable.

## Testing

The project uses Swift Package Manager for unit testing. To run the tests:

```bash
cd app
swift test
```

Note: `LTXStudioLocalApp.swift` is currently excluded from the SPM target as it requires full SwiftUI app lifecycle support which is better handled by Xcode or specialized testing setups.
