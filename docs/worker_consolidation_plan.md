# Plan: Consolidating Worker and Worker_v2

## 1. Investigation Summary
The investigation revealed that the project currently has two parallel worker implementations: `worker` (legacy/alternate) and `worker_v2` (active).
- **Active Worker:** `worker_v2` is the version currently launched by `scripts/run-worker.sh`.
- **Legacy/Alternate Worker:** `worker` contains an older version named `ltx-worker`.
- **Dependency Confusion:** The user reported that deleting `worker` causes issues. This is likely because:
    - Many documents, GitHub workflows, and architectural diagrams still point to the `worker/` path.
    - Some logs indicate that the environment might have been previously configured to use paths within the `worker/` directory.
    - `worker_v2` contains a confusing `worker/tests/` subdirectory.
    - The SwiftUI application's documentation and some hardcoded paths in scripts (other than `run-worker.sh`) might still expect the `worker/` directory.

## 2. Proposed Plan: Unify as `worker`
To resolve the confusion and follow the `AGENTS.md` guidelines, we should move the `worker_v2` implementation into the `worker` directory and eliminate the duplication.

### Step 1: Preparation
- [ ] Back up any unique data in the current `worker` folder (e.g., specific logs or legacy tests that might still be useful).
- [ ] Ensure `worker_v2` is in a clean state (stop any running processes).

### Step 2: Merging Implementation
- [ ] Delete the contents of the legacy `worker` directory.
- [ ] Move all contents from `worker_v2` to `worker`.
- [ ] Remove the `worker_v2` directory.
- [ ] Resolve the nested `worker/worker/tests/` structure by moving those tests to `worker/tests/`.

### Step 3: Updating References
- [ ] Update `scripts/run-worker.sh` to point to the `worker` directory instead of `worker_v2`.
- [ ] Update `scripts/install-worker.sh` (if it exists) to use the `worker` directory.
- [ ] Update `scripts/bootstrap.sh` to ensure it sets up the `worker` directory correctly.
- [ ] Update any references to `worker_v2` in the SwiftUI application (if any).
- [ ] Update `README.md` and other documentation files to remove mentions of `worker_v2`.
- [ ] Update GitHub Actions (`.github/workflows/`) to target the consolidated `worker` directory.

### Step 4: Verification
- [ ] Run `scripts/run-worker.sh` and verify the worker starts correctly from the `worker` directory.
- [ ] Run the SwiftUI application and verify it can communicate with the worker.
- [ ] Run tests in the consolidated `worker/tests/` directory.
- [ ] Verify that deleting the (now removed) `worker_v2` directory does not cause any further issues.

## 3. Benefits
- **Consistency:** Aligns with the project's architectural guidelines.
- **Simplicity:** One single source of truth for the Python worker.
- **Maintainability:** Reduces the risk of updating the wrong worker implementation.
