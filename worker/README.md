# LTX Studio Local Worker

This is the Python-based generation worker for LTX Studio Local.

## Requirements

- Python 3.11 or newer
- Apple Silicon Mac (for real generation, though mock works everywhere)

## Setup

1. From the project root, run:
   ```bash
   ./scripts/run-worker.sh
   ```

## Development

To run tests:
```bash
./scripts/test.sh
```

## API Endpoints

- `GET /health`: Check worker status
- `GET /hardware`: Get local hardware information
- `GET /models`: List available LTX models
- `POST /generate/text-to-video`: Start a mock generation job
- `GET /jobs/{job_id}`: Check status of a generation job
