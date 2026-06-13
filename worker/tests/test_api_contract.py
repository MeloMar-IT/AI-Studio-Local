import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from ltx_worker.main import app
from ltx_worker.schemas.api import (
    HealthResponse,
    HardwareResponse,
    ModelsResponse,
    JobStatus,
    ErrorResponse
)

client = TestClient(app)

# Helper to validate response against a Pydantic model
def validate_response(response, model):
    assert response.status_code < 400, f"Response failed with {response.status_code}: {response.text}"
    try:
        model.model_validate(response.json())
    except ValidationError as e:
        pytest.fail(f"Response validation failed for {model.__name__}: {e}")

def validate_error_response(response, status_code=None):
    if status_code:
        assert response.status_code == status_code
    else:
        assert response.status_code >= 400

    try:
        ErrorResponse.model_validate(response.json())
    except ValidationError as e:
        pytest.fail(f"Error response validation failed: {e}")

### Success Schema Tests ###

def test_health_schema():
    response = client.get("/health")
    validate_response(response, HealthResponse)

def test_hardware_schema():
    response = client.get("/hardware")
    validate_response(response, HardwareResponse)

def test_models_schema():
    response = client.get("/models")
    validate_response(response, ModelsResponse)

def test_generate_text_to_video_schema():
    payload = {
        "prompt": "Test prompt",
        "model_id": "ltx-2.3-distilled"
    }
    response = client.post("/generate/text-to-video", json=payload)
    validate_response(response, JobStatus)

def test_generate_image_to_video_schema():
    payload = {
        "prompt": "Test prompt",
        "model_id": "ltx-2.3-distilled",
        "image_path": "/tmp/test.jpg"
    }
    response = client.post("/generate/image-to-video", json=payload)
    validate_response(response, JobStatus)

def test_get_job_schema():
    # Create a job first
    payload = {"prompt": "test", "model_id": "ltx-2.3-distilled"}
    res = client.post("/generate/text-to-video", json=payload)
    job_id = res.json()["job_id"]

    response = client.get(f"/jobs/{job_id}")
    validate_response(response, JobStatus)

### Error Schema Tests ###

def test_job_not_found_error_schema():
    response = client.get("/jobs/non-existent-id")
    validate_error_response(response, 404)

def test_invalid_payload_error_schema():
    # Sending a string instead of expected object for generation
    response = client.post("/generate/text-to-video", content="not a json")
    assert response.status_code in [400, 422, 415] # 415 is Unsupported Media Type
    validate_error_response(response)

def test_invalid_field_type_schema():
    payload = {
        "prompt": "Test",
        "model_id": "ltx-2.3-distilled",
        "width": "not-an-int"
    }
    response = client.post("/generate/text-to-video", json=payload)
    assert response.status_code == 422
    validate_error_response(response)

### OpenAPI Validation ###

def test_openapi_valid():
    response = client.get("/openapi.json")
    assert response.status_code == 200
    openapi_spec = response.json()
    assert openapi_spec["openapi"].startswith("3.")
    assert "paths" in openapi_spec
    assert "components" in openapi_spec

    # Check for key endpoints in OpenAPI
    paths = openapi_spec["paths"]
    assert "/health" in paths
    assert "/hardware" in paths
    assert "/models" in paths
    assert "/generate/text-to-video" in paths
    assert "/jobs/{job_id}" in paths
