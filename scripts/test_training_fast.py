import sys
import os
import shutil
from pathlib import Path
import mlx.core as mx
import numpy as np
from safetensors.numpy import save_file

# Add the packages to path
sys.path.append(str(Path("ltx-2-mlx-repo/packages/ltx-trainer/src")))
sys.path.append(str(Path("ltx-2-mlx-repo/packages/ltx-core-mlx/src")))
sys.path.append(str(Path("ltx-2-mlx-repo/packages/ltx-pipelines-mlx/src")))

from ltx_trainer_mlx.trainer import LtxvTrainer
from ltx_trainer_mlx.config import (
    LtxTrainerConfig, ModelConfig, LoraConfig,
    OptimizationConfig, DataConfig, ValidationConfig
)

def create_mock_dataset(data_dir):
    latents_dir = os.path.join(data_dir, "latents")
    conditions_dir = os.path.join(data_dir, "conditions")
    audio_latents_dir = os.path.join(data_dir, "audio_latents")
    os.makedirs(latents_dir, exist_ok=True)
    os.makedirs(conditions_dir, exist_ok=True)
    os.makedirs(audio_latents_dir, exist_ok=True)

    # 337920 / (15*22) = 1024.
    # Sequence length in LTX: (H/patch_h) * (W/patch_w) * ((F-1)/patch_t + 1)
    # H/32 * W/32 * ((F-1)/8 + 1)
    # If H=480, W=704 (div 32), F=97.
    # 15 * 22 * 13 = 4290. Still not matching their 337920.
    # Wait, the rope cos_f/sin_f are precomputed for a MAX resolution.
    # LTX-2.3 max is usually around 1280x720.
    # 1280/32=40, 720/32=22.5.
    # The error says (1, 32, 330, 64) vs (1, 32, 337920, 64).
    # 330 is exactly 15*22. So my patchification resulted in 330 tokens.
    # The rope wants 337920 tokens. 337920 / 330 = 1024.
    # This implies there is a factor of 1024 missing, or the rope is 3D and flattened strangely.
    # Let's try to match exactly what it wants by increasing resolution/frames.
    # Or just check rope.py to see how it computes indices.

    # Actually, I'll just change the training strategy to audio only or similar if I can,
    # but that's complex. Let's just try to get a 5-step run by matching dimensions.
    latent = np.zeros((1, 128, 1, 15, 22), dtype=np.float32)
    # Mock audio latent: [batch, channels1, frames, channels2] (Audio is 4D in patchifier)
    # AudioPatchifier expects B, C1, T, C2
    audio_latent = np.zeros((1, 1, 512, 128), dtype=np.float32)
    # Mock text conditioning
    prompt_embeds = np.zeros((1, 4096, 3072), dtype=np.float32)
    prompt_mask = np.ones((1, 4096), dtype=np.bool_)

    save_file({
        "latents": latent[0], # Remove batch dim as dataloader adds it
        "num_frames": np.array([1], dtype=np.int32),
        "height": np.array([15*32], dtype=np.int32),
        "width": np.array([22*32], dtype=np.int32),
    }, os.path.join(latents_dir, "sample_0.safetensors"))
    save_file({
        "latents": audio_latent[0],
        "num_frames": np.array([512], dtype=np.int32),
        "height": np.array([1], dtype=np.int32),
        "width": np.array([1], dtype=np.int32),
    }, os.path.join(audio_latents_dir, "sample_0.safetensors"))
    save_file({
        "prompt_embeds": prompt_embeds[0],
        "prompt_attention_mask": prompt_mask[0],
        "latent_mean": np.zeros((128,), dtype=np.float32),
        "latent_std": np.ones((128,), dtype=np.float32),
    }, os.path.join(conditions_dir, "sample_0.safetensors"))

    print(f"Created mock dataset in {data_dir}")

def run_fast_test():
    data_dir = "mock_training_data"
    create_mock_dataset(data_dir)

    # Configure for 4-bit to ensure it fits in 32GB RAM
    config = LtxTrainerConfig(
        model=ModelConfig(
            model_path="models/ltx-2.3-mlx",
            training_mode="lora",
            transformer_file="transformer-dev.safetensors"
        ),
        lora=LoraConfig(
            rank=8,
            alpha=16,
            target_modules=["to_q", "to_k", "to_v"] # Exclude to_out for now to see if it simplifies
        ),
        optimization=OptimizationConfig(
            learning_rate=1e-4,
            steps=3,
            batch_size=1
        ),
        data=DataConfig(
            preprocessed_data_root=data_dir
        ),
        validation=ValidationConfig(
            interval=None # Disable validation
        ),
        output_dir="fast_test_output"
    )

    print("Starting fast training test...")
    try:
        trainer = LtxvTrainer(config)
        output_path, stats = trainer.train()
        print(f"Success! LoRA saved to {output_path}")
    except Exception as e:
        print(f"Training failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    run_fast_test()
