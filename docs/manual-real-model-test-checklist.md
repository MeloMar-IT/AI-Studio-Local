# Manual Real-Model Test Checklist

This document provides a checklist for manually testing LTX Studio Local with real LTX/MLX models on an Apple Silicon Mac. These tests ensure that the end-to-end generation pipeline is working correctly in a real-world environment.

## 1. Hardware Requirements

- [ ] **Apple Silicon Mac**: M1, M2, M3, or M4 (Pro, Max, or Ultra recommended).
- [ ] **Unified Memory**:
    - 16GB (Minimum for quantized models / Fast Draft)
    - 32GB or more (Recommended for Balanced/Production profiles)
- [ ] **Disk Space**: At least 20GB free for models and generated outputs.
- [ ] **macOS**: 14.0 (Sonoma) or newer.

## 2. Environment Requirements

### Python Environment
- [ ] **Python Version**: 3.11 or newer.
- [ ] **Virtual Environment**: Active (`source worker/venv/bin/activate`).
- [ ] **Dependencies**: Installed via `pip install -e .` in the `worker/` directory.

### External Tools
- [ ] **MLX Check**: Verify MLX is installed and working:
  ```bash
  python -c "import mlx.core as mx; print(mx.default_device())"
  ```
  *Expected Output: `Device(gpu, 0)`*
- [ ] **ffmpeg Check**: Verify ffmpeg is installed (required for video encoding):
  ```bash
  ffmpeg -version
  ```

## 3. Model Setup

- [ ] **Model Directory**: Ensure the models directory exists (default is `models/` in the project root).
- [ ] **Model Files**: LTX-Video MLX weights should be present in the models directory.
    - Example structure: `models/ltx-video-0.1-mlx/` containing `.safetensors` and config files.
- [ ] **Model Validation**: Check if the worker can see the models:
  ```bash
  curl http://localhost:8000/api/v1/models
  ```
  *Ensure the expected model ID appears in the response.*

## 4. Worker Configuration

To run with real models, the worker must be started with the correct environment variables:

```bash
export LTX_WORKER_ENVIRONMENT=production
export LTX_WORKER_ENGINE_TYPE=ltx
export LTX_WORKER_MODELS_DIR=../models
./scripts/run-worker.sh
```

## 5. Text-to-Video Test

- [ ] **Action**: Submit a text-to-video request through the App or via `curl`.
- [ ] **Test Prompt**: `"A cinematic shot of a futuristic city with flying vehicles, sunset background, high detail."`
- [ ] **Command (curl)**:
  ```bash
  curl -X POST http://localhost:8000/api/v1/generate/text-to-video \
    -H "Content-Type: application/json" \
    -d '{
      "prompt": "A cinematic shot of a futuristic city with flying vehicles, sunset background, high detail.",
      "width": 768,
      "height": 512,
      "num_frames": 24,
      "steps": 20
    }'
  ```
- [ ] **Monitor Logs**: Watch the worker logs for stages: `loading_model`, `generating_video`, `encoding_output`.

## 6. Image-to-Video Test

- [ ] **Action**: Submit an image-to-video request.
- [ ] **Input Image**: Use a clear 768x512 JPEG/PNG image.
- [ ] **Test Prompt**: `"The waves gently crashing on the shore."`
- [ ] **Command (curl)**:
  ```bash
  curl -X POST http://localhost:8000/api/v1/generate/image-to-video \
    -H "Content-Type: application/json" \
    -d '{
      "prompt": "The waves gently crashing on the shore.",
      "image_path": "/path/to/your/image.jpg",
      "width": 768,
      "height": 512,
      "num_frames": 24,
      "steps": 20
    }'
  ```

## 7. Expected Artifacts

After a successful generation, verify the following files exist in the project/scene directory:

- [ ] **Video Output**: `output.mp4` (Playable, correct resolution and duration).
- [ ] **Preview Image**: `preview.jpg` (Representative frame from the video).
- [ ] **Metadata**: `metadata.json` containing:
    - `prompt` and `composed_prompt`
    - `model_profile` and `model_path`
    - `seed`
    - `steps`, `guidance`, `fps`
    - `generation_duration`

## 8. Export Test

- [ ] **Action**: Use the "Export" feature in the App to combine multiple scenes.
- [ ] **Expected Output**: A single `.mp4` file containing all selected scenes in sequence.
- [ ] **Verify**: Audio (if applicable) and brand overlays are correctly applied.

## 9. Troubleshooting

| Issue | Potential Cause | Action |
| :--- | :--- | :--- |
| **Out of Memory (OOM)** | Model too large for RAM | Use a quantized model or lower resolution/frames. |
| **Worker fails to start** | Missing dependencies | Run `pip install -e .` and check `python` version. |
| **Model not found** | Incorrect `MODELS_DIR` | Check `LTX_WORKER_MODELS_DIR` environment variable. |
| **Slow generation** | Low memory or background apps | Close other heavy applications (browser, IDE). |
| **Invalid output** | ffmpeg missing or failing | Verify `ffmpeg` is in the system PATH. |
| **Connection Refused** | Worker not running | Run `./scripts/run-worker.sh` and check port 8000. |

---
*Note: Do not commit real model weights to the repository. Use the `.gitignore` protected `models/` directory.*
