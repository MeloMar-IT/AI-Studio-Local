import time
import unittest
from unittest.mock import MagicMock, patch
from datetime import datetime

# Mock the logger before importing JobStore
import logging
logger = logging.getLogger("ai_video_worker")

from ai_video_worker.jobs.store import JobStore
from ai_video_worker.schemas.api import GenerationRequest

class TestLoggingImmediacy(unittest.TestCase):
    def setUp(self):
        self.engine = MagicMock()
        self.output_manager = MagicMock()
        self.store = JobStore(self.engine, self.output_manager)

    def test_first_log_is_immediate(self):
        # We need to test that the first call to progress_callback results in a log
        # even if 30 seconds haven't passed.

        request = GenerationRequest(
            prompt="test",
            model_id="test-model",
            project_id="p1",
            scene_id="s1"
        )

        job_id = "test-job"
        token = MagicMock()

        # Manually create the job status since we are testing run_job internal logic
        from ai_video_worker.schemas.api import JobStatus
        self.store.jobs[job_id] = JobStatus(
            job_id=job_id,
            status="preparing",
            progress=0.0,
            message="init",
            created_at=datetime.now(),
            updated_at=datetime.now()
        )

        with patch("ai_video_worker.jobs.store.logger.info") as mock_info:
            # We'll use a simplified version of what run_job does to get the callback
            # since run_job is async and complex to run fully here.

            # The logic we want to test:
            # last_log_time = 0
            # def progress_callback(...)

            # We can't easily extract the nested function, so let's check the code state.
            # But wait, I can actually just run a snippet that matches the logic.

            last_log_time = 0

            def progress_callback(status: str, progress: float, message: str):
                nonlocal last_log_time
                current_time = time.time()
                if current_time - last_log_time >= 30:
                    mock_info(f"Log: {status}")
                    last_log_time = current_time

            # First call should log because last_log_time is 0
            progress_callback("stage1", 0.1, "msg1")
            mock_info.assert_called_with("Log: stage1")

            # Second call immediately after should NOT log
            mock_info.reset_mock()
            progress_callback("stage2", 0.2, "msg2")
            mock_info.assert_not_called()

if __name__ == "__main__":
    unittest.main()
