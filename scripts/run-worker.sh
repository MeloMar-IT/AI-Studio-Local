#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Change to worker directory
cd "$SCRIPT_DIR/../worker"

# Ensure logs directory exists, and mirror all of this script's output (stdout
# + stderr) to a shared log file as well as the terminal. run-app.sh writes to
# the same file, so app + worker output can be reviewed together in one place
# after the fact. Note: the worker process itself also writes its own
# structured logs to logs/ai-studio-local.log separately (see config.py).
LOG_DIR="$SCRIPT_DIR/../logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/run.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "===== $(date '+%Y-%m-%d %H:%M:%S') - run-worker.sh starting (pid $$) ====="

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

# Trap ctrl-c
trap 'echo "** Trapped CTRL-C / Termination"; pkill -f "ai_video_worker/main.py"; exit' INT TERM

# Check if port 8000 is already in use
if lsof -i :8000 > /dev/null 2>&1; then
    echo "⚠️ Port 8000 is already in use."
    PID=$(lsof -t -i :8000)
    echo "Process using port 8000: $PID"

    # Check if it's a previous worker process
    if ps -p "$PID" -o command | grep -q "ai_video_worker/main.py"; then
        echo "Found previous worker process. Attempting to kill it..."
        kill -9 "$PID" || true
        sleep 1
    else
        echo "❌ Port 8000 is occupied by a non-worker process. Please free it manually."
        exit 1
    fi
fi

# Run the worker
echo "Starting AI Studio Local Worker..."
export PYTHONPATH=$PYTHONPATH:.
export AI_VIDEO_WORKER_ENVIRONMENT=$ENVIRONMENT
# Disable reload to prevent interrupting long-running jobs
python3 ai_video_worker/main.py --no-reload
