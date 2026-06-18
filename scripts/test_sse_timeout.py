import requests
import time
import threading

def listen_to_events(job_id):
    url = f"http://localhost:8000/api/v1/jobs/{job_id}/events"
    print(f"Subscribing to {url}...")
    try:
        # Use a short timeout for the connection but none for the stream
        response = requests.get(url, stream=True, timeout=10)
        print(f"Status Code: {response.status_code}")
        for line in response.iter_lines():
            if line:
                print(f"Received: {line.decode('utf-8')}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    # Note: This requires a running worker and a valid job_id.
    # Since I can't easily start the worker in the background and get a job_id here without more setup,
    # I'll rely on code analysis and manual verification if I can run the worker.
    # For now, I'll just keep this script as a utility.
    print("Reproduction script created. Run it manually if a worker is active.")
