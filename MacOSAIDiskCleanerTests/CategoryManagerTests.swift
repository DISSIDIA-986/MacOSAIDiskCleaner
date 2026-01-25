import XCTest
@testable import MacOSAIDiskCleaner

final class CategoryManagerTests: XCTestCase {
    func testAllCategoriesIncludesBuiltIns() async {
        let cm = CategoryManager()
        let cats = await cm.allCategories()
        XCTAssertGreaterThanOrEqual(cats.count, 3)
        // sorted by sortOrder ascending
        let orders = cats.map { $0.sortOrder }
        XCTAssertEqual(orders, orders.sorted())
    }
}
