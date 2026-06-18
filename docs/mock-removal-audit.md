# Mock Removal Audit

This document identifies all mocks, fake data, sample-only services, and placeholders currently in the AI Studio Local repository.

## Audit Table

| File Path | Symbol/Class/Function Name | Feature Area | Current Status | Classification |
|-----------|---------------------------|--------------|----------------|----------------|
| `worker/ai_video_worker/engine/mock.py` | `MockGenerationEngine`, etc. | Generation Engine | **REMOVED** | remove-now |
| `worker/ai_video_worker/api.py` | `engine` | Worker API | **REPLACED** - LTX engine is default; mock fallback removed. | replace-with-real-code |
| `worker/ai_video_worker/api.py` | `hardware()` | Worker API | **REPLACED** - Real profiling via `profiler.py`. | replace-with-real-code |
| `worker/ai_video_worker/api.py` | `get_models()` | Worker API | **REPLACED** - Real scanning via `models.py`. | replace-with-real-code |
| `app/AIStudioLocal/Features/ProjectStudio/ProjectStudioViewModel.swift` | `exportService` | Export | **REPLACED** - Uses `AVFoundationExportService`. | replace-with-real-code |
| `app/AIStudioLocal/Services/ExportService.swift` | `MockExportService` | Export | **REMOVED** | remove-now |
| `app/AIStudioLocal/Features/ProjectStudio/ProjectStudioView.swift` | MVP demonstration code | UI / UX | **REMOVED** | remove-now |
| `app/AIStudioLocal/Domain/*.swift` | `public static var mock` | Domain Models | **ISOLATED** - Wrapped in `#if DEBUG`. | keep-as-preview-only |
| `app/AIStudioLocal/Features/ModelManager/ModelManagerView.swift` | `Offline Mode (Mock Data)` | Model Management | **UPDATED** - Now says "Disconnected from Worker". | replace-with-real-code |
| `app/AIStudioLocal/Features/ProjectStudio/ExportDialog.swift` | `MockProject.ltxproject` path | Export | **REPLACED** - Uses relative path in Documents. | replace-with-real-code |
| `worker/ai_video_worker/config.py` | `engine_type` | Configuration | **REPLACED** - Defaults to "ltx". | replace-with-real-code |
| `app/AIStudioLocal/Services/MockHardwareProfiler.swift` | `MockHardwareProfiler` | Services | **ISOLATED** - Wrapped in `#if DEBUG`. | keep-as-preview-only |

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
