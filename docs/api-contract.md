# Worker API Contract

This document defines the stable API contract between the SwiftUI application and the Python worker. These schemas are validated by automated contract tests in `worker/tests/test_api_contract.py`.

## Base Response Formats

### Success Response
All success responses for data-retrieving endpoints return the requested object directly as a JSON object matching the corresponding schema.

### Error Response
All errors (including 400, 404, 422, and 500) follow this structured format:

```json
{
  "error": {
    "code": "string",
    "message": "string",
    "detail": "optional technical detail",
    "action": "optional suggested user action"
  }
}
```

## Endpoints

### 1. Health & System
- `GET /health`: Returns service status and version.
- `GET /hardware`: Returns local hardware capabilities (Chip, RAM, OS).
- `GET /openapi.json`: Returns the full OpenAPI specification.

### 2. Model Management
- `GET /models`: Returns a list of available model profiles.

### 3. Video Generation
- `POST /generate/text-to-video`: Starts a new text-to-video job.
- `POST /generate/image-to-video`: Starts a new image-to-video job (requires `image_path`).
- `POST /generate/audio-to-video`: Starts a new audio-to-video job.
- `POST /generate/retake`: Starts a video retake job.

**Request Schema (`GenerationRequest`):**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `prompt` | string | Yes | The composed prompt text. |
| `model_id` | string | Yes | The ID of the model to use. |
| `width` | integer | No | Default: 704 |
| `height` | integer | No | Default: 480 |
| `num_frames` | integer | No | Default: 161 |
| `steps` | integer | No | Default: 20 |
| `guidance_scale` | float | No | Default: 3.0 |
| `seed` | integer | No | Random if not provided. |
| `project_id` | string | No | For metadata tracking. |
| `scene_id` | string | No | For metadata tracking. |
| `image_path` | string | No | Required for image-to-video. |

### 4. Job Management
- `GET /jobs/{job_id}`: Returns the current status of a job.
- `POST /jobs/{job_id}/cancel`: Cancels a running job.

**Response Schema (`JobStatus`):**
| Field | Type | Description |
|-------|------|-------------|
| `job_id` | string | Unique identifier. |
| `status` | string | `preparing_prompt`, `loading_model`, `generating_video`, `completed`, `failed`, `cancelled`, etc. |
| `progress` | float | 0.0 to 1.0 |
| `message` | string | User-friendly status message. |
| `created_at` | datetime | ISO format. |
| `updated_at` | datetime | ISO format. |
| `result_url` | string | Path to the generated output (if completed). |
| `error` | string | Technical error message (if failed). |

## Stability Rules
1. **No Field Deletions**: Fields currently used by the SwiftUI app must not be removed.
2. **No Type Changes**: Data types for existing fields must remain compatible.
3. **Structured Errors**: All new endpoints must use the `ErrorResponse` schema for failures.
4. **Validation**: All POST requests must return `422 Unprocessable Entity` with a structured `ErrorResponse` if validation fails.
