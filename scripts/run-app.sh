#!/bin/bash

# Navigate to the app directory
cd "$(dirname "$0")/../app"

# Run the SwiftUI application using swift run
# We remove --quiet to see SPM output
swift run LTXStudioLocal
