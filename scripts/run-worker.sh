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

# Install dependencies if needed
echo "Checking dependencies..."
if [[ "$ENVIRONMENT" == "development" ]]; then
    echo "Development mode: ensuring editable install is fresh..."
    pip install -e .
else
    # In production, only install if not already installed or if forced
    if ! pip show ai-video-worker > /dev/null 2>&1; then
        echo "Installing ai-video-worker package..."
        pip install .
    else
        echo "ai-video-worker package already installed."
    fi
fi

# Ensure logs directory exists
mkdir -p "$(dirname "$0")/../logs"

# Trap ctrl-c
trap 'echo "** Trapped CTRL-C / Termination"; pkill -f "ai_video_worker/main.py"; exit' INT TERM

# Run the worker
echo "Starting AI Studio Local Worker..."
export PYTHONPATH=$PYTHONPATH:.
export AI_VIDEO_WORKER_ENVIRONMENT=$ENVIRONMENT
python ai_video_worker/main.py
