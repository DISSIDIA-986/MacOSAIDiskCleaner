import XCTest
@testable import MacOSAIDiskCleaner

final class ScanSessionTests: XCTestCase {
    func testDurationComputation() {
        let start = Date()
        let end = start.addingTimeInterval(5)
        var session = ScanSession(
            id: UUID(),
            startedAt: start,
            categoryId: "system.caches",
            totalItemsVisited: 0,
            matchedItemsCount: 0,
            totalBytesMatched: 0,
            aiAnalyzedCount: 0,
            status: .inProgress
        )
        session.completedAt = end
        session.status = .completed
        XCTAssertEqual(session.duration, 5, accuracy: 0.001)
    }
}
