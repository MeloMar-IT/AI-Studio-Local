import XCTest
@testable import AIStudioLocal

final class GenerationClientTests: XCTestCase {
    var client: HTTPGenerationClient!
    var session: URLSession!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: configuration)
        client = HTTPGenerationClient(baseURL: URL(string: "http://localhost:8000")!, session: session)
    }

    override func tearDown() {
        client = nil
        session = nil
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testHealthResponseDecode() async throws {
        let json = """
        {
            "status": "ok",
            "version": "0.1.0",
            "uptime": 3600.5
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/health")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        let health = try await client.checkHealth()
        XCTAssertEqual(health.status, "ok")
        XCTAssertEqual(health.version, "0.1.0")
        XCTAssertEqual(health.uptime, 3600.5)
    }

    func testHardwareResponseDecode() async throws {
        let json = """
        {
            "device": "macbook_pro",
            "chip": "Apple M2 Max",
            "total_memory_gb": 64.0,
            "free_memory_gb": 32.5,
            "os_name": "macOS",
            "os_version": "14.0",
            "mlx_available": true,
            "status": "ready",
            "messages": ["All systems go"]
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/hardware")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        let hardware = try await client.fetchHardware()
        XCTAssertEqual(hardware.chip, "Apple M2 Max")
        XCTAssertEqual(hardware.totalMemoryGb, 64.0)
        XCTAssertTrue(hardware.mlxAvailable)
        XCTAssertEqual(hardware.status, "ready")
    }

    func testModelResponseDecode() async throws {
        let json = """
        {
            "models": [
                {
                    "id": "ltx-2.3-distilled",
                    "name": "LTX-2.3 Distilled",
                    "description": "Fast draft",
                    "family": "LTX-Video",
                    "expected_files": ["model.safetensors"],
                    "supported_modes": ["text-to-video"],
                    "installed": true,
                    "status": "installed",
                    "recommended": true,
                    "missing_files": [],
                    "version": "1.0",
                    "recommended_hardware": "Apple Silicon",
                    "memory_requirement_gb": 32
                }
            ],
            "models_dir": "/path/to/models"
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/models")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        let models = try await client.fetchModels()
        XCTAssertEqual(models.count, 1)
        XCTAssertEqual(models[0].id, "ltx-2.3-distilled")
        XCTAssertEqual(models[0].family, .ltxVideo)
    }

    func testErrorResponseDecode() async throws {
        let json = """
        {
            "error": {
                "code": "insufficient_memory",
                "message": "Not enough RAM",
                "action": "Close some apps"
            }
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        let request = GenerationRequest(prompt: "test", modelId: "test-model", projectId: "p1", sceneId: "s1")

        do {
            _ = try await client.submitTextToVideo(request: request)
            XCTFail("Should have thrown workerError")
        } catch GenerationClientError.workerError(let code, let message, let action) {
            XCTAssertEqual(code, "insufficient_memory")
            XCTAssertEqual(message, "Not enough RAM")
            XCTAssertEqual(action, "Close some apps")

            let appError = GenerationClientError.workerError(code: code, message: message, action: action).asAppError
            XCTAssertEqual(appError.title, "Insufficient Memory")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testGenerationRequestEncoding() async throws {
        let request = GenerationRequest(
            prompt: "A beautiful sunset",
            negativePrompt: "low quality",
            width: 704,
            height: 480,
            numFrames: 161,
            steps: 25,
            guidanceScale: 7.5,
            seed: 42,
            modelId: "ltx-2.3",
            projectId: "project-123",
            sceneId: "scene-456"
        )

        MockURLProtocol.requestHandler = { urlRequest in
            XCTAssertEqual(urlRequest.url?.path, "/generate/text-to-video")
            XCTAssertEqual(urlRequest.httpMethod, "POST")

            guard let stream = urlRequest.httpBodyStream else {
                XCTFail("Missing body stream")
                return (HTTPURLResponse(), Data())
            }

            stream.open()
            var data = Data()
            let bufferSize = 1024
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: bufferSize)
                if read > 0 {
                    data.append(buffer, count: read)
                } else {
                    break
                }
            }
            buffer.deallocate()
            stream.close()

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                XCTAssertEqual(json["prompt"] as? String, "A beautiful sunset")
                XCTAssertEqual(json["negative_prompt"] as? String, "low quality")
                XCTAssertEqual(json["width"] as? Int, 704)
                XCTAssertEqual(json["num_frames"] as? Int, 161)
                XCTAssertEqual(json["guidance_scale"] as? Double, 7.5)
                XCTAssertEqual(json["seed"] as? Int, 42)
                XCTAssertEqual(json["model_id"] as? String, "ltx-2.3")
                XCTAssertEqual(json["project_id"] as? String, "project-123")
                XCTAssertEqual(json["scene_id"] as? String, "scene-456")
            } else {
                XCTFail("Failed to parse request body")
            }

            let response = HTTPURLResponse(url: urlRequest.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let responseData = #"{"job_id": "job-123"}"#.data(using: .utf8)!
            return (response, responseData)
        }

        let jobId = try await client.submitTextToVideo(request: request)
        XCTAssertEqual(jobId, "job-123")
    }

    func testWorkerUnavailableMapping() async throws {
        MockURLProtocol.requestHandler = { _ in
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost, userInfo: nil)
        }

        do {
            _ = try await client.checkHealth()
            XCTFail("Should have thrown workerUnavailable")
        } catch GenerationClientError.workerUnavailable(let error) {
            XCTAssertNotNil(error)
            let appError = GenerationClientError.workerUnavailable(error).asAppError
            XCTAssertEqual(appError.title, "Worker Unavailable")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}

// MARK: - Mocking Infrastructure

class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            XCTFail("Handler is nil.")
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
