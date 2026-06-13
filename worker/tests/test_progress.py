import json
import time
from unittest.mock import patch
from fastapi.testclient import TestClient
from ltx_worker.main import app
from ltx_worker.schemas.api import ModelProfile

client = TestClient(app)

def test_cancellation_propagation():
    with patch("ltx_worker.api.scan_models") as mock_scan:
        mock_scan.return_value = [
            ModelProfile(
                id="ltx-2.3-distilled",
                name="LTX-2.3 Distilled",
                description="Fast draft generation",
                family="LTX-Video",
                version="2.3",
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
            "prompt": "Cancel test",
            "model_id": "ltx-2.3-distilled",
        }
        response = client.post("/generate/text-to-video", json=payload)
        job_id = response.json()["job_id"]

        # 2. Cancel the job
        response = client.post(f"/jobs/{job_id}/cancel")
        assert response.status_code == 200
        assert response.json()["status"] == "cancelled"

        # 3. Verify status in job store
        response = client.get(f"/jobs/{job_id}")
        assert response.status_code == 200
        assert response.json()["status"] == "cancelled"
