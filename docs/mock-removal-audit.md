# Mock Removal Audit

This document identifies all mocks, fake data, sample-only services, and placeholders currently in the LTX Studio Local repository.

## Audit Table

| File Path | Symbol/Class/Function Name | Feature Area | Current Mock Behaviour | Required Real Replacement | Classification | Risk if Left Unchanged |
|-----------|---------------------------|--------------|------------------------|---------------------------|----------------|------------------------|
| `worker/ltx_worker/engine/mock.py` | `MockGenerationEngine`, `MockModelLoader`, `MockLoraLoader`, `MockMediaEncoder` | Generation Engine | Simulates video generation by writing "mock video content" to files and using timers. | Real MLX/LTX implementation using local Apple Silicon hardware. | replace-with-real-code | User cannot generate actual videos; app is just a demo. |
| `worker/ltx_worker/api.py` | `hardware()` | Worker API | Returns static "Apple M2 Max" and "MacBook Pro" strings. | Dynamic hardware detection using `psutil`, `platform`, and Apple-specific profiling. | replace-with-real-code | Inaccurate hardware reporting on non-M2 Max machines. |
| `worker/ltx_worker/api.py` | `get_models()` | Worker API | Returns a hardcoded list of LTX 2.3 profiles. | Dynamic model discovery in the local `models/` directory. | replace-with-real-code | User cannot use models not in the hardcoded list. |
| `worker/ltx_worker/engine/ltx.py` | `# TODO: Import real MLX/LTX libraries` | Generation Engine | Placeholder for real LTX implementation; currently writes "REAL_LTX_VIDEO_DATA_MOCK". | Integration with MLX and LTX-Video-2 models. | replace-with-real-code | No real video generation capability. |
| `app/LTXStudioLocal/Services/ModelStore.swift` | `fetchModels()` | Model Management | Falls back to `ModelProfile.mocks` if the worker is offline or fails. | Strict error handling or cached data; mocks should only be for previews. | replace-with-real-code | App hides connection issues by showing fake models. |
| `app/LTXStudioLocal/Features/ProjectStudio/ProjectStudioViewModel.swift` | `exportService` | Export | Uses `MockExportService` as the default implementation. | Switch to `AVFoundationExportService`. | replace-with-real-code | Export might not work as expected or use suboptimal settings. |
| `app/LTXStudioLocal/Services/ExportService.swift` | `MockExportService` | Export | Wraps `AVFoundationExportService` but is explicitly named "Mock". | Remove the mock wrapper and use the real service directly. | remove-now | Confusing architecture; "mock" name in production paths. |
| `app/LTXStudioLocal/Features/ProjectStudio/ProjectStudioView.swift` | MVP demonstration code (lines 24-27) | UI / UX | Loads a mock project and scenes if no project is selected. | Home Dashboard should handle project selection; remove auto-loading mock. | remove-now | Clutters the UI with "Introduction Scene" when starting fresh. |
| `app/LTXStudioLocal/Services/ContinuityStore.swift` | `loadDefaultElements()` | Continuity Library | Injects a set of hardcoded "Marcel", "Modern Office", etc. elements. | User-driven library creation or a proper "starter pack" asset. | keep-as-preview-only | Users might be forced to delete "Marcel" in every new install. |
| `app/LTXStudioLocal/Domain/*.swift` | `public static var mock` / `mocks` | Domain Models | Static properties providing sample data for SwiftUI previews. | Keep for previews, but ensure they aren't used in production paths. | keep-as-preview-only | Harmless if restricted to Previews. |
| `app/LTXStudioLocal/Features/ProjectStudio/ProjectStudioView.swift` | `Spatial 2x (Placeholder)`, etc. | UI / Settings | UI labels with "(Placeholder)" suffix for advanced settings. | Implement real control logic for these parameters in the worker. | replace-with-real-code | Misleading UI; settings don't actually do anything. |
| `app/LTXStudioLocal/Features/ModelManager/ModelManagerView.swift` | `Offline Mode (Mock Data)` | Model Management | Explicitly warns it is using mock data if the worker connection fails. | Proper offline state or retry logic without fake data injection. | replace-with-real-code | Users think the app is working with local models when it's not. |
| `app/LTXStudioLocal/Features/ProjectStudio/ExportDialog.swift` | `MockProject.ltxproject` path | Export | Hardcoded `/tmp/LTXProjects/` path for MVP. | Use the actual project's filesystem location. | replace-with-real-code | Exports saved to temporary directory regardless of project location. |
| `worker/ltx_worker/config.py` | `engine_type: str = "mock"` | Configuration | Defaults to "mock" engine. | Default to "ltx" or fail if dependencies are missing in production. | replace-with-real-code | App starts in demo mode by default. |
| `app/LTXStudioLocal/DesignSystem/Components/GenerationVersionCard.swift` | `body` | UI | Uses a `Rectangle` placeholder instead of loading the actual preview image from disk. | Implement real image loading from the `previewImagePath`. | replace-with-real-code | Users cannot see what they generated without opening the file manually. |
| `app/LTXStudioLocal/Features/Home/HomeDashboardView.swift` | `body` | UI | Uses mock projects/scenes if none are found in the store. | Show empty state with "Create New Project" button. | remove-now | Confusing for new users to see "Example Project" they didn't create. |
| `app/LTXStudioLocal/Services/GenerationClient.swift` | `submitAudioToVideo`, `submitRetake` | Generation Client | Placeholders for future features. | Implement real API calls when worker supports them, or show "Not Yet Supported" error. | replace-with-real-code | Unimplemented features might appear to work but do nothing. |
| `app/LTXStudioLocal/Domain/*.swift` | `MARK: - Mock Fixtures` / `mock` | Domain Models | Static properties providing sample data for SwiftUI previews. | Keep for previews, but ensure they are isolated via `#if DEBUG`. | keep-as-preview-only | Harmless if restricted to Previews. |
| `app/LTXStudioLocal/DesignSystem/Icons/` | Icons | UI | Some icons might be placeholders or system icons instead of custom branding. | Review and replace with final assets if needed. | keep-as-preview-only | Minor aesthetic issue. |
| `SECURITY.md` | `security@example.com` | Documentation | Placeholder email for security reports. | Replace with a real contact email. | replace-with-real-code | Security researchers cannot report vulnerabilities. |
| `app/LTXStudioLocal/Features/ProjectStudio/ProjectStudioViewModel.swift` | `DefaultPromptImprovementHelper` | Prompt Engineering | Likely contains simple rule-based "improvement" (mock-like). | Integrate with a local LLM or more sophisticated template system. | replace-with-real-code | "Improve Prompt" might just add generic keywords. |

## Classification Definitions

- **remove-now**: Code that should be deleted immediately as it clutters the production path.
- **replace-with-real-code**: Mock logic that must be replaced by actual functional implementation.
- **keep-as-preview-only**: Code that is useful for SwiftUI Previews and should remain but be isolated.
- **convert-to-test-fixture**: Move mock data into test suites for unit/integration testing.
- **explicitly-unsupported**: Mark as "Coming Soon" in UI and disable functionality instead of faking it.

## Next Steps

1. Implement Environment Modes (Production/Development/Test).
2. Isolate `keep-as-preview-only` code using `#if DEBUG`.
3. Prioritize replacement of `MockGenerationEngine` with real MLX integration.
4. Clean up MVP-only hardcoded logic in `ProjectStudioView`.
