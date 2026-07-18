import requests
import json
import time

def test_generation(prompt, width, height):
    url = "http://127.0.0.1:8000/generate/text-to-video"
    payload = {
        "prompt": prompt,
        "width": width,
        "height": height,
        "steps": 10,
        "seed": 42
    }
    print(f"Testing with prompt: '{prompt}', resolution: {width}x{height}")
    try:
        response = requests.post(url, json=payload)
        response.raise_for_status()
        job = response.json()
        job_id = job["id"]
        print(f"Created job: {job_id}")

        # Poll for completion
        while True:
            status_url = f"http://127.0.0.1:8000/jobs/{job_id}"
            res = requests.get(status_url)
            res.raise_for_status()
            job_status = res.json()
            status = job_status["status"]
            print(f"Status: {status}, progress: {job_status.get('progress', 0)}")

            if status in ["completed", "failed", "cancelled"]:
                if status == "failed":
                    print(f"Job failed: {job_status.get('error')}")
                else:
                    print(f"Job completed successfully. Output: {job_status.get('output_path')}")
                break
            time.sleep(2)
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    # Ensure worker is running before running this
    test_prompt = "A majestic purple dragon flying over a crystalline lake, cinematic lighting"

    print("--- Testing 512p ---")
    test_generation(test_prompt, 704, 512)

    print("\n--- Testing 720p ---")
    test_generation(test_prompt, 1280, 720)
