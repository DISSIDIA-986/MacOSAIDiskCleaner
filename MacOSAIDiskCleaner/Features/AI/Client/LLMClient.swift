import Foundation
import os

struct LLMClient: Sendable {
    struct Configuration: Sendable {
        var baseURL: URL
        var model: String
        var timeout: TimeInterval = 30
        var maxRetries: Int = 3
        var totalTimeout: TimeInterval = 90

        init(baseURL: URL, model: String) {
            self.baseURL = baseURL
            self.model = model
        }
    }

    private let config: Configuration
    private let urlSession: URLSession

    init(config: Configuration, urlSession: URLSession = .shared) {
        self.config = config
        self.urlSession = urlSession
    }

    func chatCompletion(apiKey: String, prompt: String) async throws -> String {
        let startTime = Date()
        var lastError: Error?

        for attempt in 0..<config.maxRetries {
            // Check total timeout
            if Date().timeIntervalSince(startTime) > config.totalTimeout {
                throw DiskCleanerError.aiRequestFailed(
                    NSError(domain: "LLMClient", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Total timeout exceeded after \(attempt) attempts"
                    ])
                )
            }

            do {
                return try await performChatCompletion(apiKey: apiKey, prompt: prompt, attempt: attempt)
            } catch {
                lastError = error
                Logger.ai.warning("LLM request failed (attempt \(attempt + 1)/\(config.maxRetries)): \(error.localizedDescription)")

                // Don't retry if it's a client error (4xx) except 429 (rate limit)
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .timedOut, .networkConnectionLost, .notConnectedToInternet:
                        // Retryable network errors
                        break
                    case .badServerResponse:
                        // Server error - will retry
                        break
                    default:
                        // Non-retryable error
                        if attempt == 0 {
                            throw error
                        }
                    }
                }

                // Exponential backoff: 1s, 2s, 4s...
                let backoff = min(4.0, pow(2.0, Double(attempt)))
                try await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
            }
        }

        throw DiskCleanerError.aiRequestFailed(
            lastError ?? NSError(domain: "LLMClient", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Max retries (\(config.maxRetries)) exceeded"
            ])
        )
    }

    private func performChatCompletion(apiKey: String, prompt: String, attempt: Int) async throws -> String {
        let endpoint = config.baseURL.appendingPathComponent("v1/chat/completions")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = config.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = ChatCompletionRequest(
            model: config.model,
            messages: [
                .init(role: "user", content: prompt)
            ],
            temperature: 0.2
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DiskCleanerError.aiRequestFailed(URLError(.badServerResponse))
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "<no body>"
            Logger.ai.error("LLM error status=\(http.statusCode) body=\(msg, privacy: .private)")

            // Convert HTTP errors to retryable/non-retryable
            if http.statusCode == 429 {
                // Rate limit - retryable
                throw URLError(URLError.Code.badServerResponse)
            } else if (400..<500).contains(http.statusCode) {
                // Client error - non-retryable
                let clientError = NSError(
                    domain: "LLMClient",
                    code: http.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Client error \(http.statusCode): \(msg.prefix(200))"]
                )
                throw DiskCleanerError.aiRequestFailed(clientError)
            } else {
                // Server error - retryable
                throw URLError(URLError.Code.badServerResponse)
            }
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        return decoded.choices.first?.message.content ?? ""
    }

    func analyzeJSON(apiKey: String, prompt: String) async throws -> AIAnalysis {
        let raw = try await chatCompletion(apiKey: apiKey, prompt: prompt)
        guard let jsonData = raw.extractFirstJSONData() else {
            let noJSONError = NSError(
                domain: "LLMClient",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No JSON found in response"]
            )
            throw DiskCleanerError.aiRequestFailed(noJSONError)
        }
        do {
            return try JSONDecoder().decode(AIAnalysis.self, from: jsonData)
        } catch {
            throw DiskCleanerError.aiRequestFailed(error)
        }
    }
}

// MARK: - OpenAI compatible models

struct ChatCompletionRequest: Codable, Sendable {
    struct Message: Codable, Sendable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double?
}

struct ChatCompletionResponse: Codable, Sendable {
    struct Choice: Codable, Sendable {
        struct Message: Codable, Sendable {
            let role: String?
            let content: String
        }
        let index: Int?
        let message: Message
    }
    let choices: [Choice]
}

private extension String {
    /// 尝试从文本中提取第一个 JSON 对象/数组片段。
    func extractFirstJSONData() -> Data? {
        guard let startObj = firstIndex(of: "{") ?? firstIndex(of: "[") else { return nil }
        var depth = 0
        var inString = false
        var escape = false

        for i in indices[startObj..<endIndex] {
            let ch = self[i]

            if inString {
                if escape {
                    escape = false
                    continue
                }
                if ch == "\\" {
                    escape = true
                    continue
                }
                if ch == "\"" {
                    inString = false
                }
                continue
            }

            if ch == "\"" {
                inString = true
                continue
            }

            if ch == "{" || ch == "[" { depth += 1 }
            if ch == "}" || ch == "]" {
                depth -= 1
                if depth == 0 {
                    let slice = self[startObj...i]
                    return Data(slice.utf8)
                }
            }
        }
        return nil
    }
}

