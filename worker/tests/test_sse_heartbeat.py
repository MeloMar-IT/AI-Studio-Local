import json
import time
from fastapi.testclient import TestClient
from ai_video_worker.main import app
from unittest.mock import patch
from ai_video_worker.schemas.api import ModelProfile

client = TestClient(app)

def test_job_events_heartbeat():
    """Verify that the job events stream sends heartbeats."""
    with patch("ai_video_worker.api.scan_models") as mock_scan:
        mock_scan.return_value = [
            ModelProfile(
                id="ltx-video-2b-v0.9",
                name="LTX-Video 2B v0.9",
                description="Production quality base model",
                family="LTX-Video",
                version="0.9",
                expected_files=[],
                memory_requirement_gb=0,
                supported_modes=["text-to-video"],
                recommended_hardware="Any",
                installed=True,
                missing_files=[]
            )
        ]

        # 1. Create a job
        payload = {
            "prompt": "Heartbeat test",
            "model_id": "ltx-video-2b-v0.9",
        }
        response = client.post("/generate/text-to-video", json=payload)
        job_id = response.json()["job_id"]

        # 2. Subscribe to events and check for heartbeat
        # We use a context manager with stream=True
        with client.stream("GET", f"/jobs/{job_id}/events") as response:
            assert response.status_code == 200

            # Read first few lines
            lines = []
            line_count = 0
            for line in response.iter_lines():
                if line:
                    lines.append(line)
                    line_count += 1
                if line_count >= 2: # Should get heartbeat and first state
                    break

            # One of them should be a heartbeat
            has_heartbeat = any(": heartbeat" in l for l in lines)
            assert has_heartbeat, f"Heartbeat not found in first lines: {lines}"

            # One of them should be the initial state data
            has_data = any("data: {" in l for l in lines)
            assert has_data, f"Initial state data not found in first lines: {lines}"
