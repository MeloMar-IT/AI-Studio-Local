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

def run_verify_generation():
    print(f"Starting verification generation for a 'Bright green robotic duck'...")

    payload = {
        "prompt": "A bright green robotic duck swimming in a purple lake, neon highlights, cinematic, high quality",
        "negative_prompt": "man, person, human, blurry, low quality",
        "width": 512,
        "height": 512,
        "num_frames": 49,
        "steps": 10,
        "guidance_scale": 7.5,
        "seed": 99999,
        "model_id": TEST_MODEL_ID
    }

    response = requests.post(f"{BASE_URL}/generate/text-to-video", json=payload)
    if response.status_code != 200:
        print(f"Failed to create job: {response.text}")
        return

    job = response.json()
    job_id = job["job_id"]
    print(f"Job created: {job_id}")

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
        print("\nPolling interrupted.")
        return

    if status == "completed":
        print("\nSUCCESS: Verification generation completed!")
        output_dir = os.path.join("outputs", job_id)
        print(f"Check output at: {output_dir}")
    else:
        print(f"\nFAILURE: Generation {status}")
        if job.get("error"):
            print(f"Error: {job.get('error')}")

if __name__ == "__main__":
    if not check_worker_ready():
        print("Worker is not running. Please start it with AI_VIDEO_WORKER_ENGINE_TYPE=ltx")
        sys.exit(1)

    run_verify_generation()
