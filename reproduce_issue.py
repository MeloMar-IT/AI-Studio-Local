import os
import sys
import logging

# Configure logging to see what's happening
logging.basicConfig(level=logging.INFO)

try:
    from mlx_lm import load
    import mlx.core as mx
    from mlx_video.models.ltx.text_encoder import LTXTextEncoder
    print("Dependencies available")
except ImportError as e:
    print(f"Missing dependency: {e}")
    sys.exit(1)

def test_enhancement():
    # Use a dummy or lightweight model if possible, but here we just want to see if we can trigger the KeyError
    # The issue reported Gemma-3-12b-it-bf16 was used.
    model_path = "mlx-community/gemma-3-12b-it-bf16"

    # Check if model exists locally to avoid long download
    models_dir = os.path.expanduser("~/.cache/huggingface/hub")
    # Actually, the worker uses a specific models dir.

    print(f"Attempting to load model {model_path} (this might take a while if not cached)...")
    try:
        # We don't want to actually load the whole 12B model if we can avoid it,
        # but the KeyError might be in the processor initialization or usage.

        # Let's just try to initialize the LTXTextEncoder and call enhance_t2v
        # We might need to mock the language_model if we don't want to load 24GB

        encoder = LTXTextEncoder()
        # Mocking the load to only load the processor/tokenizer
        from transformers import AutoProcessor
        encoder.processor = AutoProcessor.from_pretrained(model_path)
        encoder.language_model = "MOCK" # Should fail later but let's see how far it gets

        prompt = "mlx"
        print(f"Testing enhancement with prompt: '{prompt}'")

        # Simulate enhance_t2v logic up to the point of failure
        system_prompt = encoder.default_t2v_system_prompt
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"user prompt: {prompt}"},
        ]
        formatted = encoder._apply_chat_template(messages)
        print(f"Formatted: {formatted}")

        inputs = encoder.processor(
            formatted,
            return_tensors="np",
            add_special_tokens=False,
        )
        print("Processor call successful")

    except Exception as e:
        print(f"Caught expected/unexpected error: {type(e).__name__}: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_enhancement()
