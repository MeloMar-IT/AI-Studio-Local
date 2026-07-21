import pytest
from unittest.mock import MagicMock
from ai_video_worker.engine.mlx_adapter import MLXLTXAdapter
from ai_video_worker.engine.base import UnsupportedCapabilityError

@pytest.mark.asyncio
async def test_mlx_adapter_train_lora_unsupported():
    """
    Test that MLXLTXAdapter.train_lora now raises UnsupportedCapabilityError.
    """
    adapter = MLXLTXAdapter()
    request = MagicMock()
    request.element_id = "test_element"

    with pytest.raises(UnsupportedCapabilityError) as excinfo:
        await adapter.train_lora(request, "/tmp/output")

    assert "not currently supported" in str(excinfo.value)
    assert "LTX-2" in str(excinfo.value)

def test_mlx_adapter_capabilities_no_lora():
    """
    Test that lora-training is removed from capabilities.
    """
    adapter = MLXLTXAdapter()
    assert "lora-training" not in adapter.capabilities()
