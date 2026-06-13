# Manual Real Generation Test

This document describes how to manually verify the real text-to-video generation flow once MLX/LTX dependencies are installed.

## Prerequisites

1.  **Apple Silicon Mac**: Required for MLX.
2.  **MLX installed**: `pip install mlx`
3.  **LTX Model weights**: Download and import an LTX model through the Model Manager or manually place it in the `models/` directory.

## Steps to Verify

### 1. Start the Worker

Run the worker in "ltx" engine mode:

```bash
LTX_WORKER_ENGINE_TYPE=ltx python -m ltx_worker.main
```

### 2. Verify Capabilities

Check if the worker reports `text-to-video` capability:

```bash
curl http://localhost:8000/api/v1/health
```

### 3. Trigger Generation

Send a request to the text-to-video endpoint. Replace `ltx-2.3-distilled` with your actual model ID.

```bash
curl -X POST http://localhost:8000/api/v1/generate/text-to-video \
     -H "Content-Type: application/json" \
     -d '{
       "prompt": "A cinematic shot of a robot painting on a canvas",
       "model_id": "ltx-2.3-distilled",
       "width": 704,
       "height": 480,
       "num_frames": 161
     }'
```

### 4. Monitor Progress

Use the `job_id` from the previous response to poll for status:

```bash
curl http://localhost:8000/api/v1/jobs/<job_id>
```

Expect to see stages like `loading_model`, `generating_video`, `upscaling`, etc.

### 5. Verify Artifacts

Once the job is `completed`, check the output directory:

```bash
ls -l worker/outputs/<job_id>/
```

You should see:
- `output.mp4`: The generated video.
- `preview.jpg`: A preview frame.
- `metadata.json`: Full generation metadata.
- `composed-prompt.md`: The final prompt used.

### 6. Verify Metadata Completeness

Open `metadata.json` and ensure it contains:
- `generation_id`
- `model_id`
- `prompt`
- `resolution`
- `seed`
- `device_info` (machine, memory, etc.)
- `generation_time_seconds`
