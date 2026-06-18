# User Experience Guidelines

AI Studio Local is designed as a professional creative tool for macOS, not a developer-focused experiment. The UX should feel native, responsive, and intuitive for creators.

## Core Design Principles

1. **Native Mac Feel**: Use standard macOS design patterns, sidebars, inspectors, and typography.
2. **Progressive Disclosure**: Hide advanced technical settings (CFG, Samplers, Seeds) behind "Advanced" sections.
3. **Local-First Confidence**: Always show that the data is stored locally and no cloud connection is required for generation.
4. **Actionable Feedback**: When things go wrong, explain *why* and *how to fix it* (e.g., "Not enough memory, try lowering resolution").

## Key Application Areas

### Home Dashboard
The starting point for all users. It shows recent projects and provides quick access to the Continuity Library and Model Manager.

![Home Dashboard Placeholder](https://via.placeholder.com/800x500?text=Home+Dashboard+Screenshot)

### Project Studio
The primary workspace for building video projects.
- **Scene List**: A vertical list of scenes in the project.
- **Scene Inspector**: A right-side panel for editing scene details, prompts, and attaching continuity elements.
- **Preview Area**: Shows the currently selected generation for a scene.

![Project Studio Placeholder](https://via.placeholder.com/800x500?text=Project+Studio+Screenshot)

### Continuity Library
A global management area for reusable characters, locations, and styles. It uses a category-based sidebar and a grid/list of elements.

![Continuity Library Placeholder](https://via.placeholder.com/800x500?text=Continuity+Library+Screenshot)

### Model Manager
A simplified interface for managing local AI models. Instead of showing complex file paths, it uses "Profiles" (e.g., "Fast Draft", "Production Quality").

### Render Queue
A persistent area to monitor the progress of background generation jobs. It shows clear stages like "Loading Model", "Generating", and "Encoding".

## Language and Tone

Avoid raw technical ML jargon in the primary UI.

| Technical Term | User-Friendly Term |
|----------------|--------------------|
| CFG Scale      | Prompt Strength    |
| Checkpoint     | Model Profile      |
| Inference Steps| Quality            |
| Latent Space   | Creative Variation |

## Empty States

Every list and grid must have a helpful empty state that guides the user on what to do next. For example, the Continuity Library shows a "Create your first Character" button when empty.

## Dark Mode First

The application is optimized for dark mode to provide a focused creative environment, consistent with other professional video editing tools.
