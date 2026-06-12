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

# Install dependencies
echo "Installing dependencies..."
pip install -e .

# Run the worker
echo "Starting LTX Studio Local Worker..."
export PYTHONPATH=$PYTHONPATH:.
python ltx_worker/main.py
