# AI Studio Local Worker

This is the Python-based generation worker for AI Studio Local.

## Requirements

- Python 3.11 or newer (Native ARM64 for MLX)
- Apple Silicon Mac (for real generation and MLX LoRA training)

## Environment

The project uses a local virtual environment in `worker/venv`.

To install or sync dependencies into the active environment without creating `.venv`:
```bash
cd worker
source venv/bin/activate
uv sync --active
```

## Setup

1. From the project root, run:
   ```bash
   ./scripts/run-worker.sh
   ```

## Diagnostics

To verify your MLX environment and architecture:
```bash
/Users/marcelkoert/IdeaProjects/AI Studio Local/worker/venv/bin/python ../scripts/verify_mlx_environment.py
```

## Development

To run tests:
```bash
./scripts/test.sh
```

## MLX LoRA Training

- **Requires Apple Silicon**: MLX training only works on ARM64 macOS.
- **Native Interpreter**: The worker must be running with a native ARM64 Python interpreter.
- **Active Environment**: Training uses the same interpreter and environment as the worker (no `uv run` subprocesses).

## API Endpoints

- `GET /health`: Check worker status
- `GET /hardware`: Get local hardware information
- `GET /models`: List available LTX models
- `POST /generate/text-to-video`: Start a generation job
- `GET /jobs/{job_id}`: Check status of a generation job
