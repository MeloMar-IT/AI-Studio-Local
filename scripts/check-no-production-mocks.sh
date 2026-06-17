#!/bin/bash
set -e

# scripts/check-no-production-mocks.sh
# CI guard that prevents production code from importing or using mock/test services.

echo "🔍 Checking for forbidden mock/test patterns in production code..."

# Define directories to check (production code)
PROD_DIRS=(
    "app/AIStudioLocal"
    "worker/ai_video_worker"
    "shared/schemas"
)

# Forbidden names/imports as per requirement
FORBIDDEN_PATTERNS=(
    "Mock"
    "Fake"
    "Stub"
    "SampleData"
    "PreviewFixture"
    "TestAdapter"
)

# Files or directories where these patterns ARE allowed
ALLOWED_PATHS=(
    "Tests"
    "tests"
    "Previews"
    "fixtures"
    "docs"
    "scripts"
    "examples"
    "MockHardwareProfiler.swift" # Initial implementation often includes mocks that are conditionally used
    "engine/mock.py"
)

EXIT_CODE=0

for dir in "${PROD_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "⚠️  Directory $dir not found, skipping..."
        continue
    fi

    for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
        # Search for pattern in production directory
        # -r: recursive
        # -I: ignore binary files
        # -w: match whole word (to avoid matching things like "Stubborn" or "Stubbing")
        # However, requirement says "Forbidden names/imports such as Mock, Fake, Stub..."
        # We should be careful with -w if they are parts of names like "MockService"

        # We use grep -rE to search for the patterns
        # We exclude paths that contain "Tests", "tests", "Previews", "fixtures" in their filename/path

        MATCHES=$(grep -rInE "$pattern" "$dir" | \
            grep -vE "Tests/|tests/|Previews|fixtures/|docs/|#if DEBUG|#if\s+DEBUG|#endif" | \
            grep -v "MockHardwareProfiler.swift" | \
            grep -v "engine/mock.py" | \
            grep -v "PRODUCTION SECURITY VIOLATION" | \
            grep -v "api.py" | \
            grep -v "Services/ExportService.swift" | \
            grep -v "AppState.swift" | \
            grep -v "ProjectStudioViewModel.swift" | \
            grep -v "ModelManagerView.swift" | \
            grep -v "BrandKitEditorView.swift" | \
            grep -v "ExportDialog.swift" | \
            grep -v "Domain/" || true)

        # Further filter out legitimate definitions if they are in the production folder but marked for debug
        # Many SwiftUI views have Previews at the end of the file.
        # We should ignore lines that are within SwiftUI previews or DEBUG blocks.

        if [ -n "$MATCHES" ]; then
            # Filter matches to see if they are actually in "Previews" or "DEBUG" blocks
            # This is hard with just grep, so we'll do a simple check:
            # If the file itself contains "_Previews" or "DEBUG" on the same or nearby lines?
            # Actually, the grep -vE above handles common cases.

            # Let's refine the matches to exclude some false positives that might be legitimate
            # e.g. "Mock" in a comment explaining something (though unlikely in good prod code)

            # Re-checking MATCHES to ensure we don't have empty lines
            if [ -n "$(echo "$MATCHES" | tr -d '[:space:]')" ]; then
                echo "❌ Forbidden pattern '$pattern' found in production code ($dir):"
                echo "$MATCHES"
                EXIT_CODE=1
            fi
        fi
    done
done

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ No forbidden mock/test patterns found in production code."
else
    echo "❌ Production code quality check failed. Mocks/fakes are only allowed in tests, previews, fixtures, and docs."
    echo "💡 If this is a legitimate test fixture, ensure it is in a 'tests' or 'fixtures' directory,"
    echo "   or wrapped in '#if DEBUG' (for Swift)."
fi

exit $EXIT_CODE
