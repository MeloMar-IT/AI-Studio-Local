import requests
import time
import json
import os
import sys

# Configuration
BASE_URL = "http://127.0.0.1:8000"
TEST_MODEL_ID = "ltx-video-v1"

def check_worker_ready():
    try:
        response = requests.get(f"{BASE_URL}/health")
        return response.status_code == 200
    except requests.exceptions.ConnectionError:
        return False

def run_enhanced_generation():
    print(f"Starting ENHANCED test for generating a running horse using {TEST_MODEL_ID}...")
    print("This will use Gemma-based prompt enhancement.")

    payload = {
        "prompt": "A beautiful brown horse running across a green meadow, highly detailed, cinematic lighting",
        "negative_prompt": "blurry, low quality, distorted, extra legs",
        "width": 512,
        "height": 512,
        "num_frames": 81,
        "steps": 20, # Increased steps for better quality
        "guidance_scale": 7.0,
        "seed": 12345,
        "enhance_prompt": True,
        "use_uncensored_enhancer": False,
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
    try:
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

            time.sleep(2)
    except KeyboardInterrupt:
        print("\nPolling interrupted. Job is still running on the worker.")
        return

    if status == "completed":
        print("\nSUCCESS: Enhanced Generation completed!")
        output_dir = os.path.join("outputs", job_id)
        if os.path.exists(output_dir):
            files = os.listdir(output_dir)
            print(f"Files in output directory: {files}")

            # Check for enhanced prompt in metadata
            metadata_path = os.path.join(output_dir, "metadata.json")
            if os.path.exists(metadata_path):
                with open(metadata_path, "r") as f:
                    metadata = json.load(f)
                    print(f"Original Prompt: {metadata.get('request_summary', {}).get('prompt')}")
                    # We might need to check if the worker logs the enhanced prompt or if it's in metadata

            if "output.mp4" in files:
                print(f"Successfully generated horse video at: {os.path.join(output_dir, 'output.mp4')}")
    else:
        print(f"\nFAILURE: Generation {status}")
        if job.get("error"):
            print(f"Error: {job.get('error')}")

if __name__ == "__main__":
    if not check_worker_ready():
        print("Worker is not running. Please ensure the worker is running with AI_VIDEO_WORKER_ENGINE_TYPE=ltx")
        sys.exit(1)

    run_enhanced_generation()
