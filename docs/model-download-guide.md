# Model Download Guide

AI Studio Local runs models locally on your Mac using the [MLX framework](https://github.com/ml-explore/mlx). To generate video, you must download the specific LTX-Video model weights formatted for MLX.

## Recommended Models

For the best experience on Apple Silicon, we recommend using quantized models which require less memory (RAM) while maintaining high quality.

### 1. LTX-Video (MLX Format)

The primary model used by AI Studio Local.

*   **Model**: LTX-Video v0.1
*   **Format**: MLX Safetensors
*   **Source**: [Hugging Face - Lightricks LTX-Video](https://huggingface.co/Lightricks/LTX-Video) (Original)
*   **MLX Conversion**: You can find pre-converted MLX weights on Hugging Face (search for `ltx-video-mlx`) or convert them yourself using the MLX conversion scripts.

### 2. Standard Model Structure

The worker expects the following directory structure in the root of the project:

```text
ai-studio-local/
└── models/
    └── ltx-video-0.1-mlx/
        ├── config.json
        ├── model.safetensors (or multiple .safetensors files)
        ├── scheduler_config.json
        └── ... (other required files)
```

## How to Download

1.  **Create the models directory**:
    ```bash
    mkdir -p models/ltx-video-0.1-mlx
    ```

2.  **Download from Hugging Face**:
    You can use the `huggingface-cli` to download the specific repository.
    ```bash
    pip install huggingface_hub
    huggingface-cli download mlx-community/ltx-video-0.1-mlx --local-dir models/ltx-video-0.1-mlx
    ```
    *(Note: Replace `mlx-community/ltx-video-0.1-mlx` with the actual MLX-converted repo you choose.)*

## Configuring Model Paths

If you prefer to store models in a different location (e.g., an external drive), you can set the `AI_VIDEO_WORKER_MODELS_DIR` environment variable:

```bash
export AI_VIDEO_WORKER_MODELS_DIR="/Volumes/ExternalSSD/AI_Models"
make run-worker
```

## Troubleshooting Model Loading

*   **Missing Files**: Ensure `config.json` and the `.safetensors` files are directly inside the model folder (e.g., `models/ltx-video-0.1-mlx/config.json`).
*   **Corrupt Downloads**: If the worker crashes during "Loading Model", try re-downloading the weights.
*   **Memory Issues**: If you have 16GB of RAM or less, look for "4-bit" or "8-bit" quantized MLX models.
