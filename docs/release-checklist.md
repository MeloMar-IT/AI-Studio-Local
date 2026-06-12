# Release Checklist

This checklist must be completed before any release of LTX Studio Local.

## Pre-Release
- [ ] All tests pass on `develop` branch (Swift and Python).
- [ ] All linting checks pass.
- [ ] JSON schemas are valid and examples match.
- [ ] Documentation is up to date with the latest features and changes.
- [ ] `CHANGELOG.md` has been updated with changes since the last release.
- [ ] Version numbers have been bumped in:
    - [ ] `app/LTXStudioLocal/Info.plist` (or project settings)
    - [ ] `worker/pyproject.toml`
- [ ] All `TODO` comments related to the release version are resolved.

## Verification
- [ ] Fresh installation of the Python worker works as expected.
- [ ] The SwiftUI app builds and runs without immediate crashes.
- [ ] Basic "Happy Path" verification:
    - [ ] Create a new project.
    - [ ] Add a scene.
    - [ ] Mock a generation.
    - [ ] Save and reload the project.
    - [ ] Export a scene (mock).

## Final Polish
- [ ] No debug logs are being printed to console in production mode.
- [ ] No secrets or hardcoded local paths are present in the code.
- [ ] Screenshots for App Store or documentation are updated if GUI changed significantly.

## Release Execution
- [ ] Merge `develop` into `main`.
- [ ] Tag the release in Git (e.g., `v0.1.0`).
- [ ] Create a GitHub Release with the changelog summary.
- [ ] Verify the release build (if applicable).
