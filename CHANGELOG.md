# CHANGELOG

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-06-12

### Added
- Native macOS SwiftUI application shell.
- Home Dashboard with project management and templates.
- Project Studio with scene editing and timeline visualization.
- Continuity Library for managing reusable Characters, Locations, and Styles.
- Scene Inspector with support for attaching continuity elements and consistency locks.
- Prompt Composer service for combining scene prompts with library elements.
- Model Manager with support for model profiles and mock hardware profiling.
- FastAPI-based Python worker with job lifecycle management and mock generation.
- Shared JSON schema architecture for App-to-Worker communication.
- Comprehensive project documentation and development setup guides.
- Unit test suites for Swift domain, services, and Python API.

### Fixed
- Multiple SwiftUI compilation errors and structural issues in Project Studio.
- Continuity Element encoding/decoding inconsistencies in tests.
- UI layout issues in Element Picker and Scene History.

### Changed
- Refactored Continuity Library to use a centralized store in AppState.
- Enhanced ElementChip to support removal actions and consistent iconography.

## [0.1.1] - 2026-07-17

### Added
- Created `worker_v2` with a cleaner, real-world LTX generation architecture.
- Improved metadata preservation for generated clips.

### Fixed
- Fixed "'str' object is not callable" error in MLXLTXAdapter when switching between model types.
- Fixed an issue where the worker would fail to reload a model if the ID matched but the pipeline was unloaded.

### Changed
- Redirected the SwiftUI app and all scripts to use the new `worker_v2` implementation.
- Bumped worker version to 0.1.1.

## [Unreleased]

### Added
- Initial repository structure and documentation (Phase 0).
