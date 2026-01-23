import XCTest
@testable import MacOSAIDiskCleaner

final class RuleTests: XCTestCase {
    func testGlobMatcherNodeModules() throws {
        let matcher = RuleMatcher(rules: BuiltInRules.all)
        let path = "/Users/me/Projects/demo/node_modules/react/index.js"
        let match = matcher.match(path: path)
        XCTAssertEqual(match?.rule.id, "node_modules")
    }

    func testGlobMatcherDerivedData() throws {
        let matcher = RuleMatcher(rules: BuiltInRules.all)
        let path = "/Users/me/Library/Developer/Xcode/DerivedData/Foo-abc/Build/Intermediates.noindex"
        let match = matcher.match(path: path)
        XCTAssertEqual(match?.rule.id, "xcode.deriveddata")
    }

    func testActiveProjectHeuristicNodeModules() throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }

        let project = tmp.appendingPathComponent("proj", isDirectory: true)
        try fm.createDirectory(at: project, withIntermediateDirectories: true)

        // create node_modules and a file under it
        let nodeModules = project.appendingPathComponent("node_modules", isDirectory: true)
        try fm.createDirectory(at: nodeModules, withIntermediateDirectories: true)
        let file = nodeModules.appendingPathComponent("a.js")
        try Data("x".utf8).write(to: file)

        // create lock file with recent mtime to mark project active
        let lock = project.appendingPathComponent("package-lock.json")
        try Data("{}".utf8).write(to: lock)

        let matcher = RuleMatcher(
            rules: BuiltInRules.all,
            options: .init(activeProjectDays: 365)
        )
        let match = matcher.match(path: file.path)
        XCTAssertEqual(match?.rule.id, "node_modules")
        XCTAssertEqual(match?.isActiveProject, true)
    }
}

