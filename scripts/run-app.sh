#!/bin/bash

# Navigate to the app directory
cd "$(dirname "$0")/../app"

# Parse arguments
ENVIRONMENT="production"
if [[ "$1" == "--dev" ]]; then
    ENVIRONMENT="development"
    echo "Running in DEVELOPMENT mode..."
else
    echo "Running in PRODUCTION mode..."
fi

# Run the SwiftUI application using swift run
# We remove --quiet to see SPM output
# We can pass environment as an argument or env var if the app supports it
# For now, we use an environment variable that the app might check
export LTX_APP_ENVIRONMENT=$ENVIRONMENT
swift run AIStudioLocal
