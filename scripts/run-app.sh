#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Navigate to the app directory
cd "$SCRIPT_DIR/../app"

# Ensure logs directory exists, and mirror all of this script's output (stdout
# + stderr) to a shared log file as well as the terminal. run-worker.sh writes
# to the same file, so app + worker output can be reviewed together in one
# place after the fact.
LOG_DIR="$SCRIPT_DIR/../logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/run.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "===== $(date '+%Y-%m-%d %H:%M:%S') - run-app.sh starting (pid $$) ====="

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

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT TERM

function ctrl_c() {
        echo "** Trapped CTRL-C / Termination"
        # We don't necessarily need to kill the worker here because the app
        # now handles its own cleanup on termination, but as a fallback:
        pkill -f "ai_video_worker/main.py"
        exit
}

swift run AIStudioLocal

# When the app stops, optionally kill the worker if it's still running
pkill -f "ai_video_worker/main.py"
