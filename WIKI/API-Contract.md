# API Contract

This document defines the stable API contract between the SwiftUI application and the Python worker. This contract ensures that both components can be developed and updated independently as long as they adhere to these communication rules.

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

**Generation Request Parameters:**
- `prompt`: The fully composed prompt string.
- `model_id`: ID of the model profile to use.
- `width` / `height`: Resolution settings.
- `steps`: Number of sampling steps.
- `guidance_scale`: Influence of the prompt on the result.
- `seed`: Reproducibility seed.

### 4. Job Management
- `GET /jobs/{job_id}`: Returns the current status and progress of a job.
- `POST /jobs/{job_id}/cancel`: Request cancellation of a running job.

## Job Status Lifecycle

Jobs progress through several stages:
1. `preparing_prompt`
2. `loading_model`
3. `generating_video`
4. `completed` | `failed` | `cancelled`

## Stability Rules
1. **No Field Deletions**: Fields currently used by the SwiftUI app must not be removed.
2. **No Type Changes**: Data types for existing fields must remain compatible.
3. **Structured Errors**: All new endpoints must use the `ErrorResponse` schema for failures.
4. **Validation**: All POST requests must return `422 Unprocessable Entity` with a structured `ErrorResponse` if validation fails.
