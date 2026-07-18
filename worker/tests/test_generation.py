import pytest
import os
import json
import asyncio
from pathlib import Path
from typing import Any, List, Optional
from ltx_worker.engine.adapter import LTXAdapter
from ltx_worker.engine.base import ProgressCallback, CancellationToken, UnsupportedCapabilityError
from ltx_worker.engine.ltx import LTXGenerationEngine
from ltx_worker.schemas.api import GenerationRequest

class FakeAdapter(LTXAdapter):
    def __init__(self):
        self.should_fail = False

    def capabilities(self) -> List[str]:
        return ["text-to-video"]

    async def load_model(self, model_profile: Any) -> Any:
        return {"status": "loaded"}

    async def unload_model(self, model_id: str) -> None:
        pass

    async def generate_text_to_video(
        self,
        request: Any,
        output_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        cancellation_token: Optional[CancellationToken] = None,
    ) -> str:
        if self.should_fail:
            raise Exception("Simulated generation failure")

        if progress_callback:
            progress_callback("generating", 0.5, "Generating...")

        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        with open(output_path, "wb") as f:
            f.write(b"fake video")
        return output_path

    async def generate_image_to_video(self, *args, **kwargs):
        raise UnsupportedCapabilityError("image-to-video")

    async def generate_audio_to_video(self, *args, **kwargs):
        raise UnsupportedCapabilityError("audio-to-video")

    async def generate_retake(self, *args, **kwargs):
        raise UnsupportedCapabilityError("retake")

@pytest.mark.asyncio
async def test_ltx_engine_metadata_and_files(tmp_path):
    output_dir = tmp_path / "outputs"
    output_dir.mkdir()
    job_id = "test-job-123"
    job_dir = output_dir / job_id
    job_dir.mkdir()
    output_path = str(job_dir / "output.mp4")

    adapter = FakeAdapter()
    engine = LTXGenerationEngine(adapter=adapter)

    request = GenerationRequest(
        prompt="A space cat",
        model_id="ltx-2.3-distilled",
        project_id="proj-1",
        scene_id="scene-1",
        width=1280,
        height=720,
        num_frames=121,
        steps=30,
        guidance_scale=7.5,
        seed=42
    )

    progress_updates = []
    def callback(status, progress, message):
        progress_updates.append((status, progress))

    result = await engine.generate_text_to_video(
        request=request,
        output_path=output_path,
        progress_callback=callback
    )

    assert result == output_path
    assert os.path.exists(output_path)
    assert os.path.exists(job_dir / "preview.jpg")
    assert os.path.exists(job_dir / "composed-prompt.md")
    assert os.path.exists(job_dir / "metadata.json")

    with open(job_dir / "metadata.json", "r") as f:
        meta = json.load(f)
        assert meta["generation_id"] == job_id
        assert meta["prompt"] == "A space cat"
        assert meta["project_id"] == "proj-1"
        assert meta["resolution"] == "1280x720"
        assert meta["seed"] == 42
        assert "preview_path" in meta
        assert "device_info" in meta

@pytest.mark.asyncio
async def test_ltx_engine_failure_metadata(tmp_path):
    output_dir = tmp_path / "outputs"
    output_dir.mkdir()
    job_id = "fail-job"
    job_dir = output_dir / job_id
    job_dir.mkdir()
    output_path = str(job_dir / "output.mp4")

    adapter = FakeAdapter()
    adapter.should_fail = True
    engine = LTXGenerationEngine(adapter=adapter)

    request = GenerationRequest(
        prompt="Failure test",
        model_id="ltx-2.3-distilled"
    )

    with pytest.raises(Exception) as excinfo:
        await engine.generate_text_to_video(request, output_path)

    assert "Simulated generation failure" in str(excinfo.value)
    # The engine itself doesn't save metadata on failure currently,
    # it's the JobStore that updates status to failed.
    # But let's check if the JobStore does it correctly in an integration test.

def test_request_validation():
    # This is more for api testing
    from fastapi.testclient import TestClient
    from ltx_worker.main import app
    client = TestClient(app)

    # Missing model_id
    payload = {"prompt": "test"}
    response = client.post("/generate/text-to-video", json=payload)
    assert response.status_code == 422 # Pydantic validation

    # Missing prompt
    payload = {"model_id": "ltx-2.3-distilled"}
    response = client.post("/generate/text-to-video", json=payload)
    assert response.status_code == 422

@pytest.mark.asyncio
async def test_job_lifecycle_integration(tmp_path):
    # Integration test using Real Engine with Fake Adapter to check JobStore flow
    from ltx_worker.jobs.store import JobStore
    from ltx_worker.engine.output import OutputManager

    output_dir = tmp_path / "outputs"
    output_dir.mkdir()
    output_manager = OutputManager(str(output_dir))

    adapter = FakeAdapter()
    engine = LTXGenerationEngine(adapter=adapter)
    job_store = JobStore(engine=engine, output_manager=output_manager)

    request = GenerationRequest(
        prompt="Integration test",
        model_id="ltx-2.3-distilled"
    )

    job_id = job_store.create_job(request)
    assert job_id is not None

    # Wait for completion
    max_retries = 50
    finished = False
    for _ in range(max_retries):
        await asyncio.sleep(0.2)
        job = job_store.get_job(job_id)
        if job.status in ["completed", "failed", "cancelled"]:
            finished = True
            break

    assert finished
    assert job.status == "completed"
    assert job.progress == 1.0

    # Check that files were written in the right place
    job_dir = output_dir / job_id
    assert (job_dir / "output.mp4").exists()
    assert (job_dir / "preview.jpg").exists()
    assert (job_dir / "metadata.json").exists()

    with open(job_dir / "metadata.json", "r") as f:
        meta = json.load(f)
        assert meta["status"] == "completed"
        assert "generation_id" in meta

def test_model_missing_validation():
    from fastapi.testclient import TestClient
    from ltx_worker.main import app
    client = TestClient(app)

    payload = {
        "prompt": "test",
        "model_id": "non-existent-model"
    }
    response = client.post("/generate/text-to-video", json=payload)
    assert response.status_code == 400
    data = response.json()
    assert data["error"]["code"] == "model_not_found"
