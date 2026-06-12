import requests
import time
import json
import os
import sys

# Configuration
BASE_URL = "http://127.0.0.1:8000"
MODELS_DIR = "models"
TEST_MODEL_ID = "ltx-2.3-distilled"

def check_worker_ready():
    try:
        response = requests.get(f"{BASE_URL}/health")
        return response.status_code == 200
    except requests.exceptions.ConnectionError:
        return False

def setup_test_model():
    """Create a dummy model directory for testing."""
    model_path = os.path.join(MODELS_DIR, TEST_MODEL_ID)
    if not os.path.exists(model_path):
        print(f"Creating mock model directory at {model_path}")
        os.makedirs(model_path, exist_ok=True)
        # Create a dummy config file
        with open(os.path.join(model_path, "config.json"), "w") as f:
            json.dump({"model_id": TEST_MODEL_ID}, f)

def run_test_generation():
    print("Starting manual test for real LTX generation path...")

    payload = {
        "prompt": "A cinematic shot of a sunset over a digital ocean, vaporwave style",
        "negative_prompt": "blurry, low quality",
        "width": 704,
        "height": 480,
        "num_frames": 161,
        "steps": 5,  # Fewer steps for faster test
        "guidance_scale": 3.0,
        "seed": 42,
        "model_id": TEST_MODEL_ID
    }

    response = requests.post(f"{BASE_URL}/generate/text-to-video", json=payload)
    if response.status_code != 200:
        print(f"Failed to create job: {response.text}")
        return

    job = response.json()
    job_id = job["job_id"]
    print(f"Job created: {job_id}")

    # Poll for status
    last_status = None
    while True:
        status_response = requests.get(f"{BASE_URL}/jobs/{job_id}")
        if status_response.status_code != 200:
            print(f"Failed to get job status: {status_response.text}")
            break

        job = status_response.json()
        status = job["status"]
        progress = job["progress"]
        message = job["message"]

        if status != last_status:
            print(f"Status: {status} | Progress: {progress*100:.1f}% | Message: {message}")
            last_status = status

        if status in ["completed", "failed", "cancelled"]:
            break

        time.sleep(1)

    if status == "completed":
        print("\nSUCCESS: Generation completed!")
        print(f"Result URL: {job.get('result_url')}")

        # Verify files exist
        output_dir = os.path.join("outputs", job_id)
        if not os.path.exists(output_dir):
             # Try relative to script if running from elsewhere? No, should be root.
             print(f"Warning: output_dir {output_dir} not found locally.")
        else:
            files = os.listdir(output_dir)
            print(f"Files in output directory: {files}")

            required_files = ["output.mp4", "preview.jpg", "metadata.json"]
            for f in required_files:
                if f in files:
                    print(f"  ✓ {f} exists")
                else:
                    print(f"  ✗ {f} missing")

            # Check metadata content
            metadata_file = os.path.join(output_dir, "metadata.json")
            if os.path.exists(metadata_file):
                with open(metadata_file, "r") as f:
                    metadata = json.load(f)
                    print("\nMetadata check:")
                    print(f"  Prompt: {metadata.get('prompt')}")
                    print(f"  Generation Time: {metadata.get('generation_time_seconds')}s")
                    print(f"  Model ID: {metadata.get('model_id')}")
                    print(f"  Resolution: {metadata.get('resolution')}")
    else:
        print(f"\nFAILURE: Generation {status}")
        if job.get("error"):
            print(f"Error: {job.get('error')}")

if __name__ == "__main__":
    if not check_worker_ready():
        print("Worker is not running. Please start it with: LTX_WORKER_ENGINE_TYPE=ltx uvicorn ltx_worker.main:app --reload")
        sys.exit(1)

    setup_test_model()
    run_test_generation()
