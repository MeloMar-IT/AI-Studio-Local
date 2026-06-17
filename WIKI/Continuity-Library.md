# Continuity Library

The Continuity Library is a global reusable element system used across projects in LTX Studio Local. It allows users to define and maintain consistency for characters, locations, styles, and other creative building blocks.

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
