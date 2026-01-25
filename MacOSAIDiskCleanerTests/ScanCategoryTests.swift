import XCTest
@testable import MacOSAIDiskCleaner

final class ScanCategoryTests: XCTestCase {
    func testCodableRoundTripWithRoots() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let cat = ScanCategory(
            id: "test.cat",
            name: "Test",
            icon: "folder",
            description: "Test category",
            scanRoots: [home.appendingPathComponent("Library/Caches"), home],
            isUserDefined: true,
            sortOrder: 99
        )
        let data = try JSONEncoder().encode(cat)
        let decoded = try JSONDecoder().decode(ScanCategory.self, from: data)
        XCTAssertEqual(decoded.id, cat.id)
        XCTAssertEqual(decoded.scanRoots.count, 2)
    }

    func testBuiltInCategoriesExist() {
        XCTAssertGreaterThanOrEqual(ScanCategory.builtInCategories.count, 3)
    }
}
