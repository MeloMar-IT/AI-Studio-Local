import sys
import os
import shutil
from pathlib import Path

# Add the packages to path
sys.path.append(str(Path("ltx-2-mlx-repo/packages/ltx-trainer/src")))
sys.path.append(str(Path("ltx-2-mlx-repo/packages/ltx-core-mlx/src")))
sys.path.append(str(Path("ltx-2-mlx-repo/packages/ltx-pipelines-mlx/src")))

import mlx.core as mx
from ltx_trainer_mlx.trainer import LtxvTrainer
from ltx_trainer_mlx.config import (
    LtxTrainerConfig, ModelConfig, LoraConfig,
    OptimizationConfig, DataConfig, ValidationConfig
)
from ltx_trainer_mlx.preprocess import preprocess_dataset

def run_test_training():
    # 1. Prepare small dataset from fixtures
    # Since they are just images, and preprocess_dataset expects videos,
    # we might need to be careful. But let's see if we can just point it to a folder with images.
    # Actually, ltx-trainer-mlx might have an image-to-video strategy or we can use images as 1-frame videos.

    fixture_dir = "ltx-2-mlx-repo/tests/fixtures/keyframe_pairs"
    train_dir = "temp_training_data"
    os.makedirs(train_dir, exist_ok=True)

    # Create a dummy caption file for the hedgehog
    with open(os.path.join(fixture_dir, "hedgehog_start.txt"), "w") as f:
        f.write("A cute hedgehog in a garden.")

    # 2. Preprocess (this will encode images/videos into latents)
    print("Preprocessing fixtures...")
    preprocess_dataset(
        videos_dir=fixture_dir,
        output_dir=train_dir,
        model_dir="models/ltx-2.3-mlx",
        max_frames=1, # It's images
        gemma_model_id="mlx-community/gemma-3-4b-it-4bit" # Use a smaller gemma if possible for speed
    )

    # 3. Configure Trainer
    config = LtxTrainerConfig(
        model=ModelConfig(
            model_path="models/ltx-2.3-mlx",
            training_mode="lora"
        ),
        lora=LoraConfig(
            rank=16,
            alpha=16,
            target_modules=["to_q", "to_k", "to_v", "to_out.0"]
        ),
        optimization=OptimizationConfig(
            learning_rate=1e-4,
            steps=5, # Just 5 steps for the test
            batch_size=1
        ),
        dataset=DataConfig(
            data_root=train_dir,
            video_resolution_step=32
        ),
        validation=ValidationConfig(
            enabled=False
        ),
        output_dir="temp_output_lora"
    )

    # 4. Train
    print("Starting trainer...")
    trainer = LtxvTrainer(config)
    output_path, stats = trainer.train()
    print(f"Training complete. LoRA saved to {output_path}")
    print(f"Stats: {stats}")

if __name__ == "__main__":
    run_test_training()
