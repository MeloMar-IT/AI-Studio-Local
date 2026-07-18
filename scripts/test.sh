#!/bin/bash
set -e

# Change to worker directory
cd "$(dirname "$0")/../worker"

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
fi

# Install dev dependencies
echo "Installing dependencies..."
pip install -e ".[dev]"

# Run worker tests
echo "Running worker tests..."
export PYTHONPATH=.
export AI_VIDEO_WORKER_ENVIRONMENT=test
pytest tests/

# Run app tests
echo ""
echo "Running app tests..."
cd ../app
swift test
