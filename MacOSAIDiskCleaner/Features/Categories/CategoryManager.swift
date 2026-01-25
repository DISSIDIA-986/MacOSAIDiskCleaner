import Foundation

actor CategoryManager {
    private var categories: [ScanCategory]
    private let userCategoriesURL: URL

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MacOSAIDiskCleaner", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        self.userCategoriesURL = base.appendingPathComponent("user_categories.json")

        // 加载内置 + 用户自定义
        var all = ScanCategory.builtInCategories
        if let userData = try? Data(contentsOf: userCategoriesURL),
           let userCats = try? JSONDecoder().decode([ScanCategory].self, from: userData) {
            all.append(contentsOf: userCats)
        }
        self.categories = all.sorted { $0.sortOrder < $1.sortOrder }
    }

    func allCategories() -> [ScanCategory] {
        categories
    }

    func category(forId id: String) -> ScanCategory? {
        categories.first { $0.id == id }
    }

    func addUserCategory(_ category: ScanCategory) async throws {
        guard category.isUserDefined else {
            throw CategoryError.cannotModifyBuiltIn
        }
        categories.append(category)
        categories.sort { $0.sortOrder < $1.sortOrder }
        try await persistUserCategories()
    }

    func deleteUserCategory(id: String) async throws {
        guard let idx = categories.firstIndex(where: { $0.id == id && $0.isUserDefined }) else {
            throw CategoryError.notFound
        }
        categories.remove(at: idx)
        try await persistUserCategories()
    }

    private func persistUserCategories() async throws {
        let userCats = categories.filter { $0.isUserDefined }
        let data = try JSONEncoder().encode(userCats)
        try data.write(to: userCategoriesURL)
    }

    enum CategoryError: Error {
        case cannotModifyBuiltIn
        case notFound
    }
}
