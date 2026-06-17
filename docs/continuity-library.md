# Continuity Library

The Continuity Library is a global reusable element system used across projects in AI Studio Local. It allows users to define and maintain consistency for characters, locations, styles, and other creative building blocks.

## Core Concept

Instead of re-typing complex prompts for every scene, users can create a "Continuity Element" once and reuse it. When an element is attached to a scene, its prompt blocks and settings are automatically combined by the `PromptComposer` to create the final generation instructions.

## Element Types

The library supports the following types of elements:

- **Character**: Defines visual appearance, clothing, and traits of a person or entity.
- **Location**: Defines the setting, environment, and background details.
- **Visual Style**: Defines the artistic direction, color grading, and lighting.
- **Camera Preset**: Defines camera angles, movements, and lens characteristics.
- **Audio Identity**: Defines musical themes or sound design palettes.
- **Brand Kit**: Defines brand-specific overlays, colors, and logos.
- **Prompt Block**: Generic reusable prompt fragments.
- **LoRA Reference**: References to specific Low-Rank Adaptation models for specialized styles or characters.
- **Export Template**: Presets for final video rendering and delivery.

## Storage Format

Continuity elements are stored as individual JSON files in the user's Application Support directory:

`~/Library/Application Support/AI Studio Local/ContinuityLibrary/`

Each file is named `<uuid>.json` and follows the `ContinuityElement` schema.

### Example Element (JSON)

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "type": "character",
  "name": "Marcel",
  "description": "Lead SRE with a focused expression",
  "prompt_block": "A man in his late 30s, short dark hair, wearing a grey hoodie and glasses, focused look, sitting in front of monitors",
  "negative_prompt": "beard, hat, smiling",
  "tags": ["character", "sre"],
  "assets": [],
  "created_at": "2026-06-12T14:17:00Z",
  "modified_at": "2026-06-12T14:17:00Z"
}
```

## User Interface

The Continuity Library UI is accessible from the main navigation and provides:

- **Category Sidebar**: Quick filtering by element type.
- **Search & Filtering**: Real-time search by name, description, or tags.
- **List/Detail Layout**: A native macOS-style browsing and editing experience.
- **Prompt Editor**: Specialized fields for editing prompt blocks and negative prompts.
- **Empty States**: Helpful guidance when no elements are found or selected.

### Creating Continuity Elements

1. Navigate to the **Continuity Library** in the sidebar.
2. Select a category (e.g., Characters).
3. Click the **+** button or **Add Element**.
4. Fill in the name, description, and the specific prompt fragment that defines this element.
5. Add relevant tags.
6. The element is automatically saved to `~/Library/Application Support/AI Studio Local/ContinuityLibrary/`.

## Integration with Scenes

When a user is in the Project Studio, they can attach elements from the library to any scene. These attachments are stored in the project's `scene.json` file as references (by ID).

The `PromptComposer` service is responsible for resolving these IDs and building the final prompt sent to the generation worker.

### Consistency Locks

In addition to attaching elements, users can apply "Consistency Locks" to a scene. These locks instruct the `PromptComposer` and eventually the worker to keep certain aspects stable across generations, such as:
- Seed (exact same latent starting point)
- Visual Style
- Character Identity
- Camera Angle

## Current Implementation Status

- **UI**: Element listing, filtering, and detail editing are implemented.
- **Persistence**: JSON-based storage in Application Support is functional.
- **Scene Attachment**: Elements can be picked and attached to scenes in the Project Studio.
- **Prompt Composition**: The `PromptComposer` correctly resolves attached elements and merges their prompt blocks.

## Default Elements

On first launch, the application populates the Continuity Library with a set of high-quality sample elements to help users get started.
