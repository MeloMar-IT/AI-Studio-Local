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
source venv/bin/activate

# Install dev dependencies
echo "Installing dependencies..."
pip install -e ".[dev]"

# Run worker tests
echo "Running worker tests..."
export PYTHONPATH=.
export LTX_WORKER_ENVIRONMENT=test
pytest tests/

# Run app tests
echo ""
echo "Running app tests..."
cd ../app
swift test
