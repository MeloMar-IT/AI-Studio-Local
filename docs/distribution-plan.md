# Distribution Plan: AI Studio Local

This document outlines the strategy for packaging and distributing AI Studio Local as a native macOS application, both via direct download (DMG) and the Mac App Store.

## Architecture Context
AI Studio Local consists of:
1. **SwiftUI Frontend:** The primary user interface.
2. **Python Worker:** Handles heavy ML workloads (MLX, LTX).

Distributing this hybrid setup requires bundling a Python runtime and ensuring both components are correctly signed and notarized.

---

## Stage 1: DMG Distribution (Direct Download)

This is the recommended first step as it has fewer restrictions than the App Store.

### Phase 1.1: Bundling the Python Worker
Currently, the app expects a local development environment with `python3` and `venv` available. For distribution, we must embed the environment.

- **Option A: Briefcase (Recommended)**
  - Use Beeware's `briefcase` to package the Python worker into a macOS `.app` template.
  - Advantage: Handles dependencies and binary signing of Python modules.
- **Option B: Manual Bundling**
  - Download a portable Python build (e.g., from `indygreg/python-build-standalone`).
  - Install dependencies into a folder.
  - Place the entire folder into `AIStudioLocal.app/Contents/Resources/worker`.

### Phase 1.2: App Refactoring for Portability
- **Worker Management:** Update `WorkerManager.swift` to look for the bundled Python executable first.
- **Path Resolution:** Update `FileSystemService.swift` to prioritize `Bundle.main.resourceURL?.appendingPathComponent("worker/bin/python")`.
- **Permissions:** Ensure the bundled scripts have execute permissions (`chmod +x`).

### Phase 1.3: Signing and Notarization
Modern macOS requires Notarization for apps distributed outside the App Store.

1. **Developer ID:** Obtain a "Developer ID Application" certificate from Apple.
2. **Hardened Runtime:** Enable the "Hardened Runtime" entitlement in Xcode.
3. **Signing:** Sign the `.app` bundle recursively (including the nested Python runtime and `.so` files).
4. **Notarization:** Use `xcrun notarytool` to submit the app to Apple's notarization service.
5. **Stapling:** Staple the notarization ticket to the `.app` or DMG.

### Phase 1.4: DMG Creation
Use a tool like `create-dmg` to generate a user-friendly installer.
- Add a custom background.
- Include a shortcut to `/Applications`.
- Set the volume icon.

---

## Stage 2: Mac App Store Distribution

App Store distribution is significantly more restrictive due to **App Sandboxing**.

### Phase 2.1: Sandboxing Compliance
- **Subprocesses:** Sandboxed apps generally cannot launch arbitrary shell scripts or Python interpreters.
- **XPC Services:** The "Apple Way" is to move the worker into an XPC Service. This is technically challenging for a large Python environment.
- **Alternative:** Investigate if the Python worker can be bundled as a Helper Tool with appropriate entitlements.

### Phase 2.2: Communication Migration
- **Local API:** FastAPI over HTTP on a local port is generally discouraged in sandboxed apps.
- **Unix Domain Sockets:** Migrate communication to Unix Domain Sockets within the App Group container.

### Phase 2.3: App Store Review Preparation
- **Privacy:** Document all local data usage.
- **Hardware Requirements:** Explicitly state the need for Apple Silicon and minimum Unified Memory (e.g., 16GB+).
- **In-App Purchases:** If any cloud features are added, they must use IAP.

---

## Implementation Roadmap

| Stage | Task | Priority | Status |
| :--- | :--- | :--- | :--- |
| **DMG** | Embed Portable Python | High | Planned |
| **DMG** | Refactor WorkerManager for Bundled Path | High | Planned |
| **DMG** | Setup Signing/Notarization Script | Medium | Planned |
| **App Store** | Sandbox Feasibility Study (MLX in Sandbox) | Medium | Planned |
| **App Store** | XPC Service Prototype | Low | Planned |

## Recommendations
1. **Focus on DMG first.** The flexibility of direct distribution is better suited for the heavy Python dependencies used by LTX/MLX.
2. **Use `briefcase`.** It is the most mature tool for bridging the gap between Python and macOS App packaging.
3. **Automate.** Create a `Makefile` target `dist-dmg` that handles bundling, signing, and packaging in one command.
