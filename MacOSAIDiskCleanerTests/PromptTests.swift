import XCTest
@testable import MacOSAIDiskCleaner

final class PromptTests: XCTestCase {
    func testPathSanitizerUserHome() {
        let input = "/Users/alice/Library/Caches/com.example.app"
        let out = PathSanitizer.sanitize(input)
        XCTAssertTrue(out.hasPrefix("~/Library/Caches/"))
    }

    func testPathSanitizerUUID() {
        let input = "/Users/alice/Library/Developer/Xcode/DerivedData/Foo-12345678-1234-1234-1234-1234567890ab/Build"
        let out = PathSanitizer.sanitize(input)
        XCTAssertFalse(out.contains("12345678-1234-1234-1234-1234567890ab"))
        XCTAssertTrue(out.contains("[UUID]"))
    }

    func testPromptManagerSelectsCacheTemplate() {
        let pm = PromptManager()
        let ctx = AnalysisContext(path: "/Users/alice/Library/Caches/com.example", isDirectory: true, sizeBytes: 10)
        let (id, prompt) = pm.makePrompt(context: ctx)
        XCTAssertEqual(id, "cache")
        XCTAssertTrue(prompt.contains("cache"))
        XCTAssertFalse(prompt.contains("/Users/alice"))
    }
}

