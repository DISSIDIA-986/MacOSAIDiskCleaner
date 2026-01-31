import XCTest
@testable import MacOSAIDiskCleaner

final class CandidateItemTests: XCTestCase {
    func testEffectiveRiskPrefersAI() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let rule = CleanupRule(
            id: "r",
            name: "Rule",
            kind: .glob,
            pattern: "**/test",
            riskLevel: .low,
            priority: 100
        )
        let item = CandidateItem(
            id: url, url: url, isDirectory: false, sizeBytes: 1,
            ruleMatch: RuleMatch(rule: rule, isActiveProject: false, note: nil),
            aiAnalysis: AIAnalysis(summary: "", recommendedAction: .keep, riskLevel: .high, reasons: [], warnings: [], confidence: 0.9),
            sourceCategoryId: "system.caches", scanSessionId: UUID(), scannedAt: Date()
        )
        XCTAssertEqual(item.effectiveRiskLevel, .high)
    }
}
