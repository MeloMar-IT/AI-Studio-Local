# Export Service

The `ExportService` handles concatenating scene generations from the timeline into a final MP4 video file, applying brand overlays (watermarks, title cards, lower thirds, etc.), and generating export metadata.

## Implementation Details

- **Engine:** Uses `AVFoundation` for video composition and export.
- **Validation:** Strictly validates that all timeline clips have valid scenes, generations, and that the output video files exist before starting the export.
- **Overlays:** Applied via `AVVideoCompositionCoreAnimationTool`.
- **Metadata:** Every export generates a `metadata-*.json` file in the project's `exports/` folder, containing full generation details for reproducibility.

## Errors

The export pipeline will fail with clear, actionable errors if:
- The timeline is empty.
- A scene referenced in the timeline is missing.
- A scene has no successful generations.
- A generated video file is missing from the project folder.

## Manual Smoke Test

To verify deterministic brand overlays, follow these steps:

1. **Setup Brand Kit:**
   - Open Continuity Library.
   - Create or Edit a Brand Kit.
   - Set a logo (PNG with transparency).
   - Set Intro Text: "Deterministic Overlay Test".
   - Set Outro Text: "Thank you for watching".
   - Enable Lower Thirds.

2. **Setup Project:**
   - Create a new project.
   - Add at least two scenes.
   - Generate or add video clips to these scenes.
   - Ensure the project is using the Brand Kit created in step 1.

3. **Export:**
   - Go to Export view.
   - Select "YouTube 1080p" preset.
   - Click "Export".

4. **Verification:**
   - Open the exported MP4 file.
   - **Watermark:** Verify the logo appears in the top-right corner (or configured position) with correct opacity.
   - **Intro Card:** Verify "Deterministic Overlay Test" appears centered during the first 3 seconds and then fades out.
   - **Lower Thirds:** Verify scene names appear in the bottom-left corner as each scene plays.
   - **Outro Card:** Verify "Thank you for watching" appears centered during the last 3 seconds of the video.
   - **Metadata:** Check the `exports/metadata-*.json` file and verify it contains the `brandKit` settings used.
