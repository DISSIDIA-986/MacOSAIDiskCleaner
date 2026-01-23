import Foundation

/// 控制 AI 请求并发数（默认 3）。
actor AIRequestQueue {
    private let maxConcurrent: Int
    private var running: Int = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(maxConcurrent: Int = 3) {
        self.maxConcurrent = max(1, maxConcurrent)
    }

    func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T {
        await acquire()
        defer { release() }
        return try await operation()
    }

    private func acquire() async {
        if running < maxConcurrent {
            running += 1
            return
        }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            waiters.append(cont)
        }
        running += 1
    }

    private func release() {
        running -= 1
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()
        }
    }
}

