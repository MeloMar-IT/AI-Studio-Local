import pytest
import os

# Force environment to 'test' for all tests
os.environ["LTX_WORKER_ENVIRONMENT"] = "test"

# Import settings and force it to 'test'
from ltx_worker import config
config.settings.environment = "test"

@pytest.fixture(autouse=True)
def force_test_env():
    config.settings.environment = "test"
    yield
