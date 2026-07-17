import pytest
import os
import asyncio
from pathlib import Path
from ai_video_worker.engine.ltx import LTXGenerationEngine
from ai_video_worker.schemas.api import GenerationRequest
from ai_video_worker.config import settings

@pytest.mark.asyncio
async def test_duck_generation_real():
    """
    End-to-end test producing a 2-second video of a duck.
    Uses the real MLXLTXAdapter with the AV model.
    """
    # 1. Setup paths
    output_root = Path("outputs/tests")
    output_root.mkdir(parents=True, exist_ok=True)

    job_id = "duck-test-job"
    job_dir = output_root / job_id
    if job_dir.exists():
        import shutil
        shutil.rmtree(job_dir)
    job_dir.mkdir(parents=True)

    output_path = str(job_dir / "output.mp4")

    # 2. Initialize Engine (will use MLXLTXAdapter by default)
    engine = LTXGenerationEngine()

    # 3. Create Request
    # 2 seconds at 24fps = 48 frames.
    # LTX usually likes (8n + 1) frames, so 49 frames is perfect (8*6 + 1).
    request = GenerationRequest(
        prompt="A cute yellow duck swimming in a calm blue pond, realistic, high quality, 2 seconds",
        model_id="ltx-video-av-q4", # Use the AV model we verified
        width=512,
        height=512,
        num_frames=49,
        steps=20, # Low steps for faster test
        guidance_scale=3.0,
        seed=42
    )

    print(f"\nStarting duck generation job: {job_id}")
    print(f"Prompt: {request.prompt}")
    print(f"Output: {output_path}")

    # 4. Run Generation
    def progress_callback(stage, progress, message):
        print(f"[{stage}] {progress*100:.1f}%: {message}")

    try:
        result_path = await engine.generate_text_to_video(
            request=request,
            output_path=output_path,
            progress_callback=progress_callback
        )

        # 5. Verifications
        assert result_path == output_path
        assert os.path.exists(output_path), "Output MP4 file missing"
        assert os.path.getsize(output_path) > 0, "Output MP4 file is empty"

        assert os.path.exists(job_dir / "preview.jpg"), "Preview image missing"
        assert os.path.exists(job_dir / "metadata.json"), "Metadata file missing"
        assert os.path.exists(job_dir / "composed-prompt.md"), "Composed prompt missing"

        print(f"\nSUCCESS: Duck video generated at {result_path}")

    except Exception as e:
        print(f"\nFAILURE: Duck generation failed: {e}")
        raise e

if __name__ == "__main__":
    asyncio.run(test_duck_generation_real())
