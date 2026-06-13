import pytest
import os
import json
import asyncio
from datetime import datetime
from ltx_worker.jobs.store import JobStore
from ltx_worker.engine.output import OutputManager
from ltx_worker.engine.base import GenerationEngine, CancellationToken
from ltx_worker.schemas.api import GenerationRequest, JobStatus

class MockEngine(GenerationEngine):
    def capabilities(self): return ["text-to-video"]
    async def load_model(self, model_profile): return None
    async def unload_model(self, model_id): pass
    async def generate_text_to_video(self, request, output_path, progress_callback=None, cancellation_token=None):
        if progress_callback:
            progress_callback("generating", 0.5, "Generating...")
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        with open(output_path, "w") as f: f.write("video content")
        return output_path
    async def generate_image_to_video(self, *args, **kwargs): raise NotImplementedError()
    async def generate_audio_to_video(self, *args, **kwargs): raise NotImplementedError()
    async def generate_retake(self, *args, **kwargs): raise NotImplementedError()
    async def generate(self, request, output_path, progress_callback=None, cancellation_token=None):
        return await self.generate_text_to_video(request, output_path, progress_callback, cancellation_token)

@pytest.mark.asyncio
async def test_job_metadata_persistence(tmp_path):
    output_dir = tmp_path / "outputs"
    output_manager = OutputManager(str(output_dir))
    engine = MockEngine()
    job_store = JobStore(engine=engine, output_manager=output_manager)

    request = GenerationRequest(
        prompt="Test prompt",
        model_id="test-model",
        project_id="proj-123",
        scene_id="scene-456",
        composed_prompt_path="/path/to/prompt.md"
    )

    job_id = job_store.create_job(request)

    # Wait for job to finish
    for _ in range(10):
        await asyncio.sleep(0.1)
        job = job_store.get_job(job_id)
        if job and job.status == "completed": break

    assert job is not None
    assert job.status == "completed"

    metadata_path = output_manager.get_metadata_path(job_id)
    assert metadata_path.exists()

    with open(metadata_path, "r") as f:
        meta = json.load(f)

    assert meta["job_id"] == job_id
    assert meta["project_id"] == "proj-123"
    assert meta["scene_id"] == "scene-456"
    assert meta["status"] == "completed"
    assert meta["model_profile"] == "test-model"
    assert meta["composed_prompt_path"] == "/path/to/prompt.md"
    assert "started_at" in meta
    assert "completed_at" in meta
    assert len(meta["progress_events"]) > 0
    assert meta["progress_events"][0]["status"] == "generating"

    log_path = output_manager.get_log_path(job_id)
    assert log_path.exists()
    with open(log_path, "r") as f:
        logs = f.read()
    assert "Job created" in logs
    assert "Job completed successfully" in logs

@pytest.mark.asyncio
async def test_job_recovery_and_interruption(tmp_path):
    output_dir = tmp_path / "outputs"
    output_manager = OutputManager(str(output_dir))

    # 1. Create a "running" job manually by writing metadata
    job_id = "interrupted-job"
    job_dir = output_dir / job_id
    job_dir.mkdir(parents=True)

    metadata = {
        "job_id": job_id,
        "status": "generating_video",
        "progress": 0.4,
        "created_at": datetime.now().isoformat(),
        "project_id": "p1",
        "scene_id": "s1"
    }
    with open(job_dir / "metadata.json", "w") as f:
        json.dump(metadata, f)

    # 2. Initialize JobStore, it should recover and mark as interrupted
    engine = MockEngine()
    job_store = JobStore(engine=engine, output_manager=output_manager)

    job = job_store.get_job(job_id)
    assert job is not None
    assert job.status == "interrupted"
    assert job.error == "Job interrupted by worker restart"

    # Check that disk metadata was updated
    with open(job_dir / "metadata.json", "r") as f:
        meta = json.load(f)
    assert meta["status"] == "interrupted"

@pytest.mark.asyncio
async def test_failed_job_metadata(tmp_path):
    output_dir = tmp_path / "outputs"
    output_manager = OutputManager(str(output_dir))

    class FailingEngine(MockEngine):
        async def generate_text_to_video(self, *args, **kwargs):
            raise Exception("Boom!")
        async def generate(self, *args, **kwargs):
            return await self.generate_text_to_video(*args, **kwargs)

    engine = FailingEngine()
    job_store = JobStore(engine=engine, output_manager=output_manager)

    request = GenerationRequest(prompt="Fail", model_id="m1")
    job_id = job_store.create_job(request)

    for _ in range(10):
        await asyncio.sleep(0.1)
        job = job_store.get_job(job_id)
        if job and job.status == "failed": break

    assert job is not None
    assert job.status == "failed"
    assert job.error == "Boom!"

    with open(output_manager.get_metadata_path(job_id), "r") as f:
        meta = json.load(f)
    assert meta["status"] == "failed"
    assert meta["error"] == "Boom!"
