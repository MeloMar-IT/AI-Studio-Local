import sys
import os
import argparse
import json
import shutil
from pathlib import Path

# Add ltx-2-mlx internal packages to path if not running in the repo's environment
# Assuming this script might be run either way
# __file__ = .../AI Studio Local/worker/ai_video_worker/engine/ltx_training_wrapper.py
# parents[3] = .../AI Studio Local (parents[4] would overshoot to the parent of the
# project folder and pick up an unrelated ltx-2-mlx-repo checkout if one exists there)
ROOT = Path(__file__).parents[3]
INTERNAL_PACKAGES = [
    ROOT / "ltx-2-mlx-repo/packages/ltx-trainer/src",
    ROOT / "ltx-2-mlx-repo/packages/ltx-core-mlx/src",
    ROOT / "ltx-2-mlx-repo/packages/ltx-pipelines-mlx/src",
]

for p in INTERNAL_PACKAGES:
    if str(p) not in sys.path and p.exists():
        sys.path.append(str(p))

try:
    from ltx_trainer_mlx.preprocess import preprocess_dataset
    from ltx_trainer_mlx.trainer import LtxvTrainer
    from ltx_trainer_mlx.config import LtxTrainerConfig
except ImportError as e:
    print(f"Error importing ltx_trainer_mlx: {e}")
    sys.exit(1)

def prepare_dataset(video_paths, trigger_word, temp_dir, description=None):
    """
    Prepares the directory structure for ltx-trainer.

    Captions are `trigger_word` alone if no description is given (this was
    previously the *only* option -- the caption was always just the bare
    trigger word, regardless of what the character element's description
    field said, because nothing upstream of here ever passed a description
    through). When one is provided, it's appended after the trigger word so
    the LoRA still reliably associates the exact token with this identity
    (that association is what generation prompts key off of -- see
    PromptComposer.swift's trigger-word injection) while also learning from
    the richer descriptive text, which generally helps the LoRA separate
    "this is the character" from "this is the pose/background/lighting".
    """
    videos_dir = Path(temp_dir) / "videos"
    captions_dir = Path(temp_dir) / "captions"
    videos_dir.mkdir(parents=True, exist_ok=True)
    captions_dir.mkdir(parents=True, exist_ok=True)

    description = description.strip() if description else None
    caption_text = f"{trigger_word}, {description}" if description else trigger_word

    for i, video_path in enumerate(video_paths):
        video_path = Path(video_path)
        if not video_path.exists():
            print(f"Warning: Video {video_path} not found")
            continue

        # Copy or link video
        dest_video = videos_dir / f"video_{i}{video_path.suffix}"
        if dest_video.exists():
            dest_video.unlink()
        os.link(video_path, dest_video)

        # Create caption
        caption_path = captions_dir / f"video_{i}.txt"
        with open(caption_path, "w") as f:
            f.write(caption_text)

    return videos_dir, captions_dir

def main():
    parser = argparse.ArgumentParser(description="LTX LoRA Training Wrapper")
    parser.add_argument("--model_path", required=True)
    parser.add_argument("--video_paths", required=True, help="JSON list of video paths")
    parser.add_argument("--trigger_word", required=True)
    parser.add_argument(
        "--description",
        default=None,
        help="Optional descriptive text (e.g. the character element's description field) "
        "appended after the trigger word in every caption.",
    )
    parser.add_argument("--output_dir", required=True)
    parser.add_argument("--temp_dir", required=True)
    parser.add_argument("--steps", type=int, default=500)
    parser.add_argument("--rank", type=int, default=64)
    parser.add_argument("--learning_rate", type=float, default=5e-4)
    parser.add_argument(
        "--gemma_model_path",
        default=None,
        help="Local path to the Gemma text encoder. If omitted, falls back to "
        "downloading the default HF Hub model (mlx-community/gemma-3-12b-it-4bit).",
    )

    args = parser.parse_args()

    video_paths = json.loads(args.video_paths)

    # 1. Prepare Dataset
    print(f"Preparing dataset in {args.temp_dir}...")
    videos_dir, captions_dir = prepare_dataset(video_paths, args.trigger_word, args.temp_dir, description=args.description)

    preprocessed_dir = Path(args.temp_dir) / "preprocessed"
    preprocessed_dir.mkdir(parents=True, exist_ok=True)

    # 2. Preprocess
    print("Starting preprocessing...")
    # LTX-2 MLX trainer's preprocess_dataset expects:
    # videos_dir, output_dir, model_dir, gemma_model_id, target_height, target_width, max_frames, captions_dir, ...

    # model_dir should be the directory containing the model weights (safetensors)
    model_path = Path(args.model_path)
    model_dir = str(model_path.parent if model_path.is_file() else model_path)

    preprocess_kwargs = {}
    if args.gemma_model_path:
        preprocess_kwargs["gemma_model_id"] = args.gemma_model_path

    preprocess_dataset(
        videos_dir=str(videos_dir),
        output_dir=str(preprocessed_dir),
        model_dir=model_dir,
        captions_dir=str(captions_dir),
        **preprocess_kwargs,
    )

    # 3. Train
    print("Starting training...")

    config_dict = {
        "model": {
            "model_path": args.model_path,
            "training_mode": "lora",
        },
        "lora": {
            "rank": args.rank,
        },
        # Preprocessing above never passes with_audio=True to preprocess_dataset, so no
        # audio_latents/ ever gets written to the precomputed dataset. TrainingStrategyConfig
        # defaults generate_audio=True though, so without this override PrecomputedDataset
        # unconditionally requires an audio_latents directory that doesn't exist and fails
        # at the very start of trainer.train().
        "training_strategy": {
            "generate_audio": False,
        },
        "optimization": {
            "steps": args.steps,
            "learning_rate": args.learning_rate,
        },
        "data": {
            "preprocessed_data_root": str(preprocessed_dir),
        },
        "output_dir": args.output_dir,
        "validation": {
            "interval": None, # Disable validation for speed in MVP
        }
    }

    config = LtxTrainerConfig(**config_dict)
    trainer = LtxvTrainer(config)
    trainer.train()

    print("Training finished successfully.")

if __name__ == "__main__":
    main()
