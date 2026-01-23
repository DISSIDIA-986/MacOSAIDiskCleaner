import Foundation

/// 聚合频繁更新，避免 SwiftUI 因高频 @Published 刷新而卡死。
actor BatchUpdater<Element: Sendable> {
    private var buffer: [Element] = []
    private let maxBatchSize: Int
    private let intervalNanos: UInt64
    private let flushOnMain: @MainActor @Sendable ([Element]) -> Void
    private var ticker: Task<Void, Never>?

    init(
        maxBatchSize: Int = 100,
        interval: TimeInterval = 0.5,
        flushOnMain: @escaping @MainActor @Sendable ([Element]) -> Void
    ) {
        self.maxBatchSize = max(1, maxBatchSize)
        self.intervalNanos = UInt64(max(0.05, interval) * 1_000_000_000)
        self.flushOnMain = flushOnMain
    }

    func start() {
        guard ticker == nil else { return }
        ticker = Task { [intervalNanos] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNanos)
                await flushIfNeeded()
            }
        }
    }

    func stop() {
        ticker?.cancel()
        ticker = nil
    }

    func append(_ element: Element) async {
        buffer.append(element)
        if buffer.count >= maxBatchSize {
            await flushIfNeeded()
        }
    }

    func flushIfNeeded() async {
        guard !buffer.isEmpty else { return }
        let batch = buffer
        buffer.removeAll(keepingCapacity: true)
        await MainActor.run { flushOnMain(batch) }
    }
}

