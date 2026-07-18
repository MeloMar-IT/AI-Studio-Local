import requests
import time
import json
import os

def test_generation():
    url = "http://127.0.0.1:8001/generate/text-to-video"
    payload = {
        "prompt": "a running horse",
        "enhance_prompt": True,
        "num_frames": 49,
        "steps": 20,
        "guidance_scale": 4.0,
        "seed": 42
    }

    print(f"Sending request to {url}...")
    response = requests.post(url, json=payload)
    if response.status_code != 200:
        print(f"Error: {response.status_code}")
        print(response.text)
        return

    job = response.json()
    job_id = job["job_id"]
    print(f"Job created: {job_id}")

    while True:
        status_url = f"http://127.0.0.1:8001/jobs/{job_id}"
        resp = requests.get(status_url)
        if resp.status_code != 200:
            print(f"Error getting status: {resp.status_code}")
            break

        status_data = resp.json()
        status = status_data["status"]
        progress = status_data["progress"]
        message = status_data["message"]

        print(f"Status: {status} ({progress*100:.1f}%) - {message}")

        if status in ["completed", "failed", "cancelled"]:
            if status == "completed":
                print("Generation completed successfully!")
                print(f"Result URL: {status_data.get('result_url')}")

                # Check output dir
                output_dir = f"worker_v2/outputs/{job_id}"
                if os.path.exists(output_dir):
                    print(f"Output files in {output_dir}:")
                    print(os.listdir(output_dir))

                    # Try to read metadata to see enhanced prompt
                    metadata_path = os.path.join(output_dir, "metadata.json")
                    if os.path.exists(metadata_path):
                        with open(metadata_path, 'r') as f:
                            meta = json.load(f)
                            print(f"Original prompt: {meta.get('prompt')}")
                            print(f"Composed prompt: {meta.get('composed_prompt')}")
            else:
                print(f"Generation ended with status: {status}")
                if status_data.get("error"):
                    print(f"Error: {status_data.get('error')}")
            break

        time.sleep(10)

if __name__ == "__main__":
    test_generation()
