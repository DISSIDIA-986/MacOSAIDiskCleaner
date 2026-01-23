import XCTest
@testable import MacOSAIDiskCleaner

final class ScannerTests: XCTestCase {
    func testDoesNotTraverseSymlinkedDirectory() async throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }

        let root = tmp.appendingPathComponent("root", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        // Create a normal file under root
        let normalFile = root.appendingPathComponent("a.txt")
        try "hello".data(using: .utf8)!.write(to: normalFile)

        // Create a symlink pointing to /etc (should not be traversed)
        let link = root.appendingPathComponent("etc-link")
        try fm.createSymbolicLink(at: link, withDestinationURL: URL(fileURLWithPath: "/etc", isDirectory: true))

        final class URLSetBox: @unchecked Sendable {
            var urls: Set<URL> = []
        }
        let box = URLSetBox()
        let scanner = FileScanner()

        try await scanner.scanTopLevelAggregates(
            root: root,
            onProgress: { _ in },
            onUpdate: { item in
                box.urls.insert(item.url)
            }
        )

        XCTAssertFalse(box.urls.isEmpty, "Scanner should report at least one top-level item")
        XCTAssertTrue(box.urls.contains(normalFile), "Scanner should report normal file at top-level")
        XCTAssertFalse(box.urls.contains(link), "Scanner should not traverse or report symlinked directory")
    }
}

