import argparse
import mlx.core as mx
from safetensors.numpy import save_file, load_file
import os

def remap_lora(input_path, output_path):
    print(f"Remapping LoRA: {input_path} -> {output_path}")
    weights = load_file(input_path)
    new_weights = {}

    # Map ltx-trainer-mlx keys to mlx-video expected keys
    # ltx-trainer-mlx: transformer_blocks.0.ff.proj_in
    # mlx-video (normalized): transformer_blocks.0.ff.proj_in
    # BUT mlx-video actually wants to see the keys that it can NORMALIZE to its internal model.
    # Looking at _normalize_ltx_lora_key:
    # it maps ".ff.net.0.proj" -> ".ff.proj_in"
    # So if we want it to work, we should probably give it ".ff.net.0.proj"

    mapping = {
        ".ff.proj_in": ".ff.net.0.proj",
        ".ff.proj_out": ".ff.net.2",
        ".to_out": ".to_out.0",
        ".audio_ff.proj_in": ".audio_ff.net.0.proj",
        ".audio_ff.proj_out": ".audio_ff.net.2",
    }

    for key, val in weights.items():
        new_key = key
        for src, dst in mapping.items():
            if key.endswith(src + ".lora_A"):
                new_key = key.replace(src + ".lora_A", dst + ".lora_A")
                break
            if key.endswith(src + ".lora_B"):
                new_key = key.replace(src + ".lora_B", dst + ".lora_B")
                break

        # Also handle prefixes if they exist (though ltx-trainer-mlx usually doesn't add them)
        new_weights[new_key] = val
        if new_key != key:
            print(f"  Mapped: {key} -> {new_key}")

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    save_file(new_weights, output_path)
    print("Remapping complete.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("input", help="Path to input LoRA safetensors")
    parser.add_argument("output", help="Path to output LoRA safetensors")
    args = parser.parse_args()
    remap_lora(args.input, args.output)
