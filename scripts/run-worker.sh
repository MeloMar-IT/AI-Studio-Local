#!/bin/bash
set -e

# Change to worker directory
cd "$(dirname "$0")/../worker_v2"

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
fi

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

# Ensure ltx-video and its requirements are installed (using --no-deps for ltx-video to avoid conflict with MLX suite)
if ! pip show ltx-video > /dev/null 2>&1 || ! pip show mlx-video-with-audio > /dev/null 2>&1; then
    echo "Installing ltx-video, mlx-video-with-audio and requirements..."
    pip install torch diffusers einops sentencepiece timm opencv-python
    pip install mlx>=0.20.0 mlx-vlm>=0.3.0 mlx-lm>=0.19.0 mlx-audio>=0.4.5 mlx-video-with-audio>=0.1.36
    pip install --no-deps ltx-video==0.1.2
fi

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
# Disable reload to prevent interrupting long-running jobs
python ai_video_worker/main.py --no-reload
