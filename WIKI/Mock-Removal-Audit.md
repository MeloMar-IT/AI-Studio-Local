# Mock Removal Audit

AI Studio Local is currently in an MVP state where several components use mocks or placeholders. This document tracks the status of these components and our progress toward a full, real implementation.

## Classification Definitions

- **remove-now**: Code that should be deleted immediately as it clutters the production path.
- **replace-with-real-code**: Mock logic that must be replaced by actual functional implementation.
- **keep-as-preview-only**: Code that is useful for SwiftUI Previews and should remain but be isolated.
- **explicitly-unsupported**: Mark as "Coming Soon" in UI and disable functionality instead of faking it.

## Key Audit Areas

### Python Worker
| Feature | Current Status | Target |
|---------|----------------|--------|
| Generation Engine | **Mock Adapter** | Real MLX Pipeline |
| Hardware Profiler | **Real Profiler** | Enhanced GPU/NPU tracking |
| Model Scanning | **Real Scanning** | Checksum verification |

### SwiftUI App
| Feature | Current Status | Target |
|---------|----------------|--------|
| Export Service | **AVFoundation** | Advanced multi-track rendering |
| Hardware Info | **Worker-backed** | Real-time GPU monitoring |
| Domain Mocks | **Isolated in #if DEBUG** | Pure preview usage |

## Removal Progress

We are strictly following a "No-Mock Production" policy. The `check-no-production-mocks.sh` script ensures that no code classified as `remove-now` or `replace-with-real-code` ever makes it into a production build.

### Completed Removals:
- [x] MockExportService removed.
- [x] Hardcoded pathing in ExportDialog replaced.
- [x] Worker engine default switched to "ltx".

### Remaining Work:
- [ ] Replace `MockLTXAdapter` with full `MLXLTXAdapter` implementation.
- [ ] Complete schema validation for all worker endpoints.
- [ ] Implement real-time hardware status streaming from worker to app.
