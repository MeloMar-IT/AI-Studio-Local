import pytest
import os
import json
import shutil
import tempfile
import asyncio
from ltx_worker.jobs.store import JobStore
from ltx_worker.engine.mock import MockGenerationEngine, MockModelLoader, MockLoraLoader, MockMediaEncoder
from ltx_worker.engine.output import OutputManager
from ltx_worker.schemas.api import GenerationRequest

@pytest.fixture
def temp_output_dir():
    dir_path = tempfile.mkdtemp()
    yield dir_path
    shutil.rmtree(dir_path)

def test_job_metadata_persistence(temp_output_dir):
    engine = MockGenerationEngine(MockModelLoader(), MockLoraLoader(), MockMediaEncoder())
    output_manager = OutputManager(temp_output_dir)
    store = JobStore(engine, output_manager)

    request = GenerationRequest(
        prompt="A beautiful sunset",
        model_id="test-model",
        project_id="proj-123",
        scene_id="scene-456"
    )

    import asyncio
    async def run_test():
        job_id = store.create_job(request)
        # Check if metadata file was created
        metadata_path = os.path.join(temp_output_dir, job_id, "metadata.json")
        # metadata is written after generation. so we should wait or check if it exists eventually
        # in Mock engine it is very fast.
        for _ in range(100):
            if os.path.exists(metadata_path):
                 break
            await asyncio.sleep(0.01)

        assert os.path.exists(metadata_path)

        with open(metadata_path, "r") as f:
            metadata = json.load(f)
            assert metadata["job_id"] == job_id
            assert metadata["project_id"] == "proj-123"
            assert metadata["scene_id"] == "scene-456"

    asyncio.run(run_test())

def test_output_file_structure(temp_output_dir):
    engine = MockGenerationEngine(MockModelLoader(), MockLoraLoader(), MockMediaEncoder())
    output_manager = OutputManager(temp_output_dir)
    store = JobStore(engine, output_manager)

    request = GenerationRequest(
        prompt="A beautiful sunset",
        model_id="test-model"
    )

    # We need to wait for the job to complete as it's async
    import asyncio

    async def run_and_wait():
        job_id = store.create_job(request)
        # Poll for completion
        for _ in range(200):
            job = store.get_job(job_id)
            if job.status == "completed":
                return job_id
            if job.status == "failed":
                print(f"Job failed: {job.error}")
                return job_id
            await asyncio.sleep(0.01)
        return job_id

    job_id = asyncio.run(run_and_wait())

    job_dir = os.path.join(temp_output_dir, job_id)
    assert os.path.exists(job_dir)
    assert os.path.exists(os.path.join(job_dir, "output.mp4"))
    assert os.path.exists(os.path.join(job_dir, "metadata.json"))
    assert os.path.exists(os.path.join(job_dir, "job.log"))
