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

# Parse arguments
ENVIRONMENT="production"
if [[ "$1" == "--dev" ]]; then
    ENVIRONMENT="development"
    echo "Running in DEVELOPMENT mode..."
else
    echo "Running in PRODUCTION mode..."
fi

# Install dependencies
echo "Installing dependencies..."
pip install -e .

# Ensure logs directory exists
mkdir -p "$(dirname "$0")/../logs"

# Run the worker
echo "Starting AI Studio Local Worker..."
export PYTHONPATH=$PYTHONPATH:.
export AI_VIDEO_WORKER_ENVIRONMENT=$ENVIRONMENT
python ai_video_worker/main.py
