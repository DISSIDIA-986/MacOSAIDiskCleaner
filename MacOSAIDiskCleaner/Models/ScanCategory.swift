import Foundation

struct ScanCategory: Identifiable, Hashable, Codable, Sendable {
    let id: String                          // 稳定标识符 (如 "system.caches")
    let name: String                        // 显示名称
    let icon: String                        // SF Symbol名称
    let description: String                 // 简短描述
    let scanRoots: [URL]                    // 支持多根目录
    let isUserDefined: Bool                 // 区分内置/自定义
    let associatedRuleIds: Set<String>?     // 关联规则 (可选)
    let preferredTemplateId: String?        // 首选Prompt模板
    let estimatedScanTimeSeconds: Int?      // UI提示用
    let sortOrder: Int                      // 侧边栏排序

    // 编码时需处理URL数组
    enum CodingKeys: String, CodingKey {
        case id, name, icon, description, isUserDefined
        case associatedRuleIds, preferredTemplateId
        case estimatedScanTimeSeconds, sortOrder
        case scanRootPaths  // URL序列化为路径字符串
    }

    // 自定义 Codable 实现 (URL数组序列化)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        description = try container.decode(String.self, forKey: .description)
        isUserDefined = try container.decode(Bool.self, forKey: .isUserDefined)
        associatedRuleIds = try container.decodeIfPresent(Set<String>.self, forKey: .associatedRuleIds)
        preferredTemplateId = try container.decodeIfPresent(String.self, forKey: .preferredTemplateId)
        estimatedScanTimeSeconds = try container.decodeIfPresent(Int.self, forKey: .estimatedScanTimeSeconds)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        
        let paths = try container.decode([String].self, forKey: .scanRootPaths)
        scanRoots = paths.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(icon, forKey: .icon)
        try container.encode(description, forKey: .description)
        try container.encode(isUserDefined, forKey: .isUserDefined)
        try container.encodeIfPresent(associatedRuleIds, forKey: .associatedRuleIds)
        try container.encodeIfPresent(preferredTemplateId, forKey: .preferredTemplateId)
        try container.encodeIfPresent(estimatedScanTimeSeconds, forKey: .estimatedScanTimeSeconds)
        try container.encode(sortOrder, forKey: .sortOrder)
        
        let paths = scanRoots.map { $0.path }
        try container.encode(paths, forKey: .scanRootPaths)
    }

    // 标准初始化器
    init(
        id: String,
        name: String,
        icon: String,
        description: String,
        scanRoots: [URL],
        isUserDefined: Bool,
        associatedRuleIds: Set<String>? = nil,
        preferredTemplateId: String? = nil,
        estimatedScanTimeSeconds: Int? = nil,
        sortOrder: Int
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.description = description
        self.scanRoots = scanRoots
        self.isUserDefined = isUserDefined
        self.associatedRuleIds = associatedRuleIds
        self.preferredTemplateId = preferredTemplateId
        self.estimatedScanTimeSeconds = estimatedScanTimeSeconds
        self.sortOrder = sortOrder
    }
}

extension ScanCategory {
    static let caches = ScanCategory(
        id: "system.caches",
        name: "Caches",
        icon: "archivebox",
        description: "Application and system caches",
        scanRoots: [FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches")],
        isUserDefined: false,
        associatedRuleIds: ["user.caches"],
        preferredTemplateId: "cache",
        estimatedScanTimeSeconds: 60,
        sortOrder: 0
    )

    static let developer = ScanCategory(
        id: "system.developer",
        name: "Developer",
        icon: "hammer",
        description: "Xcode and developer tool caches",
        scanRoots: [FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer")],
        isUserDefined: false,
        associatedRuleIds: ["xcode.deriveddata"],
        preferredTemplateId: "large_directory",
        estimatedScanTimeSeconds: 120,
        sortOrder: 1
    )

    static let home = ScanCategory(
        id: "system.home",
        name: "Home",
        icon: "house",
        description: "Entire home directory",
        scanRoots: [FileManager.default.homeDirectoryForCurrentUser],
        isUserDefined: false,
        associatedRuleIds: nil,
        preferredTemplateId: nil,
        estimatedScanTimeSeconds: 300,
        sortOrder: 2
    )

    static let builtInCategories: [ScanCategory] = [.caches, .developer, .home]
}
