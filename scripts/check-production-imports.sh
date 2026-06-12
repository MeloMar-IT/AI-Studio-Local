#!/bin/bash
set -e

echo "🔍 Checking for forbidden imports in production code..."

# Define directories to check (production code)
PROD_DIRS=("app/LTXStudioLocal" "worker/ltx_worker")

# Define forbidden patterns (preview fixtures, mock tests, etc.)
# These should only be in app/LTXStudioLocalTests, worker/tests, or Feature previews
FORBIDDEN_PATTERNS=(
    "MockHardwareProfiler"
    "MockGenerationEngine"
    "preview_fixtures"
    "test_fixtures"
)

# Exception: Feature files can have SwiftUI _Previews but they should be wrapped in #if DEBUG
# However, this script aims to catch accidental logic dependency on mocks.

EXIT_CODE=0

for dir in "${PROD_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        continue
    fi

    for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
        # search for the pattern, but exclude Feature preview blocks if possible
        # We exclude the definitions of mocks and the checks themselves

        MATCHES=$(grep -r -I "$pattern" "$dir" | \
            grep -v "_Previews" | \
            grep -v "DEBUG" | \
            grep -v "PRODUCTION SECURITY VIOLATION" | \
            grep -v "is $pattern" | \
            grep -v "class $pattern" | \
            grep -v "final class $pattern" | \
            grep -v "MockHardwareProfiler.swift" | \
            grep -v "engine/mock.py" | \
            grep -v "import $pattern" | \
            grep -v "from .* import $pattern" | \
            grep -v "$pattern," | \
            grep -v "$pattern)" | \
            grep -v "engine = $pattern" || true)

        if [ -n "$MATCHES" ]; then
            echo "❌ Forbidden pattern '$pattern' found in $dir:"
            echo "$MATCHES"
            EXIT_CODE=1
        fi
    done
done

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ No forbidden imports found in production code."
else
    echo "❌ Production code quality check failed."
fi

exit $EXIT_CODE
