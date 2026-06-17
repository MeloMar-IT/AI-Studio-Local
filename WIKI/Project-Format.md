# Project Format

Projects are stored as folders with the `.ltxproject` extension. This format is designed to be Git-friendly, allowing for clear versioning of prompts and settings while keeping large media files separate if needed.

## Directory Structure

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

## Key Files

- **project.json**: Stores the `Project` model, including name, IDs, and global project metadata.
- **timeline.json**: Defines the sequence and duration of scenes in the project.
- **README.md**: An automatically maintained summary of the project for easy viewing in Git platforms or file browsers.
- **scenes/<id>/scene.json**: Contains parameters for a single clip, such as resolution, duration, and attached continuity elements.
- **scenes/<id>/prompt.md**: The scene's prompt stored as plain text, ensuring clean diffs when editing your creative vision.

## Git Hygiene

AI Studio Local is optimized for Git workflows:
1. **Plain Text Prompts**: Storing prompts in `.md` files allows you to track creative changes over time.
2. **Structured JSON**: All JSON files are formatted to be human-readable and Git-friendly.
3. **Large File Handling**: Generated media (`.mp4`) and previews (`.jpg`) are stored in predictable paths, making it easy to exclude them from standard Git commits or manage them via Git LFS.

## Portability

All internal paths within the project are relative to the project root. This ensures that you can move your `.ltxproject` folder between different locations or share it with other users of AI Studio Local without breaking references.
