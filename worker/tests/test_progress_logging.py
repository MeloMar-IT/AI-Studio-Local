import pytest
import asyncio
import time
from unittest.mock import MagicMock
from ai_video_worker.jobs.store import JobStore
from ai_video_worker.schemas.api import GenerationRequest

@pytest.mark.asyncio
async def test_progress_logging_interval():
    # Mock engine and output manager
    engine = MagicMock()
    output_manager = MagicMock()

    # Store to test
    store = JobStore(engine=engine, output_manager=output_manager)

    # Mock logger to capture calls
    from ai_video_worker.jobs.store import logger
    logger.info = MagicMock()

    request = GenerationRequest(
        prompt="test prompt",
        model_id="test-model",
        project_id="test-proj",
        scene_id="test-scene"
    )

    # Capture the progress_callback passed to engine.generate
    captured_callback = None
    async def fake_generate(request, output_path, progress_callback, cancellation_token):
        nonlocal captured_callback
        captured_callback = progress_callback
        return output_path

    engine.generate = fake_generate

    # Create job
    job_id = store.create_job(request)

    # Wait for the task to reach engine.generate
    while captured_callback is None:
        await asyncio.sleep(0.01)

    # Test callback logging
    # Initial log at time 0 (within first callback call if we change logic slightly, or we can just mock time)
    with MagicMock() as mock_time:
        import ai_video_worker.jobs.store as store_mod
        original_time = store_mod.time.time

        try:
            # First call should log because it's the first one (actually run_job sets last_log_time = time.time())
            # So if we call it immediately, it's 0 seconds passed.

            # Setup mock time
            start_t = 1000.0
            store_mod.time.time = MagicMock(return_value=start_t)

            # Re-create job with mocked time to ensure predictable last_log_time
            job_id = store.create_job(request)
            while captured_callback is None:
                await asyncio.sleep(0.01)

            # 1. Call at T=1000 (0s elapsed) -> Should NOT log INFO (diff < 30)
            logger.info.reset_mock()
            captured_callback("generating", 0.1, "Step 1")
            # In current implementation, last_log_time is set at start of run_job.
            # If run_job start and first callback are same time, diff is 0.
            # logger.info should NOT be called.

            info_calls = [call for call in logger.info.call_args_list if f"Job {job_id} progress" in str(call)]
            assert len(info_calls) == 0

            # 2. Call at T=1029 (29s elapsed) -> Should NOT log INFO
            store_mod.time.time.return_value = start_t + 29
            captured_callback("generating", 0.2, "Step 2")
            info_calls = [call for call in logger.info.call_args_list if f"Job {job_id} progress" in str(call)]
            assert len(info_calls) == 0

            # 3. Call at T=1031 (31s elapsed) -> SHOULD log INFO
            store_mod.time.time.return_value = start_t + 31
            captured_callback("generating", 0.3, "Step 3")
            info_calls = [call for call in logger.info.call_args_list if f"Job {job_id} progress" in str(call)]
            assert len(info_calls) == 1
            assert "30.0%" in str(info_calls[0])

            # 4. Call at T=1040 (9s since last log) -> Should NOT log INFO
            logger.info.reset_mock()
            store_mod.time.time.return_value = start_t + 40
            captured_callback("generating", 0.4, "Step 4")
            info_calls = [call for call in logger.info.call_args_list if f"Job {job_id} progress" in str(call)]
            assert len(info_calls) == 0

            # 5. Call at T=1062 (31s since last log at T=1031) -> SHOULD log INFO
            store_mod.time.time.return_value = start_t + 62
            captured_callback("generating", 0.5, "Step 5")
            info_calls = [call for call in logger.info.call_args_list if f"Job {job_id} progress" in str(call)]
            assert len(info_calls) == 1
            assert "50.0%" in str(info_calls[0])

        finally:
            store_mod.time.time = original_time

if __name__ == "__main__":
    import sys
    pytest.main([__file__])
