import XCTest
@testable import MacOSAIDiskCleaner

final class TemplateManagerTests: XCTestCase {
    func testCacheTemplateSelectedForCachesPath() async {
        let tm = TemplateManager()
        let ctx = AnalysisContext(
            path: "/Users/test/Library/Caches/com.foo",
            isDirectory: true,
            sizeBytes: 1024,
            matchedRuleId: nil,
            matchedRuleName: nil,
            riskLevel: nil,
            isActiveProject: nil
        )
        let tpl = await tm.selectTemplate(for: ctx, category: .caches, developerProfile: nil)
        XCTAssertEqual(tpl.id, "cache")
    }

    func testLargeDirectorySelectedBySize() async {
        let tm = TemplateManager()
        let ctx = AnalysisContext(
            path: "/Users/test/Documents/Big",
            isDirectory: true,
            sizeBytes: 2_000_000_000,
            matchedRuleId: nil,
            matchedRuleName: nil,
            riskLevel: nil,
            isActiveProject: nil
        )
        let tpl = await tm.selectTemplate(for: ctx, category: nil, developerProfile: nil)
        XCTAssertEqual(tpl.id, "large_directory")
    }
}
