import Foundation
import Combine

@MainActor
final class DiskCleanerViewModel: ObservableObject {
    // 移除了嵌套 enum Category，现在使用 ScanCategory struct

    enum ScanState: Equatable {
        case idle
        case scanning
        case finished
        case failed(String)
    }

    // MARK: - Sort & Filter Options
    enum SortOrder: String, CaseIterable, Identifiable {
        case riskAsc = "Risk (Low→High)"
        case riskDesc = "Risk (High→Low)"
        case sizeDesc = "Size (Largest)"
        case sizeAsc = "Size (Smallest)"
        case nameAsc = "Name (A→Z)"

        var id: String { rawValue }
    }

    enum RiskFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case low = "Low Risk"
        case medium = "Medium Risk"
        case high = "High Risk"

        var id: String { rawValue }
    }

    @Published var selectedCategory: ScanCategory = .caches
    @Published private(set) var availableCategories: [ScanCategory] = []
    @Published private(set) var currentSession: ScanSession?
    
    @Published var sortOrder: SortOrder = .riskAsc
    @Published var riskFilter: RiskFilter = .all
    @Published private(set) var scanState: ScanState = .idle
    @Published private(set) var items: [CandidateItem] = []
    @Published private(set) var visitedFileCount: Int = 0
    @Published private(set) var scannedFileCount: Int = 0
    @Published private(set) var scannedBytes: Int64 = 0
    @Published private(set) var estimatedTotalFiles: Int = 0
    @Published private(set) var isAnalyzing: Bool = false
    @Published private(set) var analyzedCount: Int = 0
    @Published private(set) var analyzeErrorMessage: String?
    @Published var selectedURLs: Set<URL> = []
    @Published private(set) var lastTrashSummary: String?

    let permissionManager = PermissionManager()
    let settings = SettingsViewModel()

    private let categoryManager = CategoryManager()
    private let statisticsManager = StatisticsManager()
    private let scanner = FileScanner()
    private var ruleMatcher: RuleMatcher {
        RuleMatcher(rules: BuiltInRules.all, options: settings.ruleMatcherOptions())
    }
    private let aiAnalyzer = AIAnalyzer()
    private let trashManager = TrashManager()
    private var scanTask: Task<Void, Never>?
    private var itemsByURL: [URL: CandidateItem] = [:]
    private var cancellables: Set<AnyCancellable> = []

    init() {
        // Forward permission manager changes to update the UI
        permissionManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Sort & Filter
    func applySortAndFilter() {
        var filtered = Array(itemsByURL.values)

        // Apply filter
        switch riskFilter {
        case .all:
            break
        case .low:
            filtered = filtered.filter { $0.effectiveRiskLevel == .low }
        case .medium:
            filtered = filtered.filter { $0.effectiveRiskLevel == .medium }
        case .high:
            filtered = filtered.filter { $0.effectiveRiskLevel == .high }
        }

        // Apply sort
        switch sortOrder {
        case .riskAsc:
            filtered.sort {
                let l = riskOrder($0.effectiveRiskLevel)
                let r = riskOrder($1.effectiveRiskLevel)
                if l != r { return l < r }
                return $0.sizeBytes > $1.sizeBytes
            }
        case .riskDesc:
            filtered.sort {
                let l = riskOrder($0.effectiveRiskLevel)
                let r = riskOrder($1.effectiveRiskLevel)
                if l != r { return l > r }
                return $0.sizeBytes > $1.sizeBytes
            }
        case .sizeDesc:
            filtered.sort { $0.sizeBytes > $1.sizeBytes }
        case .sizeAsc:
            filtered.sort { $0.sizeBytes < $1.sizeBytes }
        case .nameAsc:
            filtered.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        items = Array(filtered.prefix(500))
    }

    func onAppear() {
        permissionManager.refresh()

        // Trigger audit.log migration if needed (one-time operation)
        Task {
            await statisticsManager.migrateFromAuditLogIfNeeded()
        }
    }

    private func buildDeveloperProfile() -> DeveloperProfile {
        DeveloperProfile(
            swift: settings.devSwift,
            python: settings.devPython,
            nodeJS: settings.devNodeJS,
            ruby: settings.devRuby
        )
    }

    func loadCategories() async {
        availableCategories = await categoryManager.allCategories()
        // 如果当前选择的分类不在列表中，回退到第一个
        if !availableCategories.contains(where: { $0.id == selectedCategory.id }) {
            selectedCategory = availableCategories.first ?? .caches
        }
    }

    func startScan() {
        scanTask?.cancel()
        permissionManager.refresh()

        guard permissionManager.fullDiskAccessStatus == .granted else {
            scanState = .idle
            items = []
            visitedFileCount = 0
            scannedFileCount = 0
            scannedBytes = 0
            return
        }

        scanState = .scanning
        items = []
        visitedFileCount = 0
        scannedFileCount = 0
        scannedBytes = 0
        estimatedTotalFiles = 0
        analyzedCount = 0
        analyzeErrorMessage = nil
        itemsByURL = [:]
        selectedURLs = []
        lastTrashSummary = nil

        // 新增: 创建扫描会话
        let sessionId = UUID()
        let now = Date()
        currentSession = ScanSession(
            id: sessionId,
            startedAt: now,
            categoryId: selectedCategory.id,
            totalItemsVisited: 0,
            matchedItemsCount: 0,
            totalBytesMatched: 0,
            aiAnalyzedCount: 0,
            status: .inProgress
        )

        // 记录会话开始到统计管理器
        if let session = currentSession {
            Task { await statisticsManager.recordSessionStart(session) }
        }

        let roots = selectedCategory.scanRoots

        // Quick estimate for progress percentage
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            var totalEstimate = 0
            for root in roots {
                totalEstimate += await self.scanner.estimateTotalFiles(root: root)
            }
            await MainActor.run {
                self.estimatedTotalFiles = totalEstimate
            }
        }

        scanTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }

            let updater = BatchUpdater<ScannedItem>(maxBatchSize: 100, interval: 0.5) { batch in
                for s in batch {
                    let existing = self.itemsByURL[s.url]
                    let match = self.ruleMatcher.match(path: s.url.path)
                    let candidate = CandidateItem(
                        id: s.url,
                        url: s.url,
                        isDirectory: s.isDirectory,
                        sizeBytes: s.sizeBytes,
                        ruleMatch: match,
                        aiAnalysis: existing?.aiAnalysis,
                        sourceCategoryId: self.selectedCategory.id,
                        scanSessionId: sessionId,
                        scannedAt: now
                    )
                    self.itemsByURL[s.url] = candidate
                }

                self.applySortAndFilter()
            }
            await updater.start()

            do {
                // 扫描每个根目录
                for root in roots {
                    try await self.scanner.scanTopLevelAggregates(
                        root: root,
                        onProgress: { progress in
                            Task { @MainActor in
                                self.visitedFileCount = progress.visitedEntries
                                self.scannedFileCount = progress.countedFiles
                                self.scannedBytes = progress.countedBytes
                            }
                        },
                        onUpdate: { item in
                            Task { await updater.append(item) }
                        }
                    )
                }
                await updater.flushIfNeeded()
                
                // 更新会话状态
                await MainActor.run {
                    self.currentSession?.completedAt = Date()
                    self.currentSession?.status = .completed
                    self.currentSession?.matchedItemsCount = self.itemsByURL.count
                    self.currentSession?.totalBytesMatched = self.scannedBytes
                    self.scanState = .finished
                }

                // 记录会话完成到统计管理器
                await self.statisticsManager.recordSessionComplete(
                    sessionId,
                    itemsMatched: self.itemsByURL.count,
                    bytesMatched: self.scannedBytes
                )
            } catch {
                await MainActor.run { self.scanState = .failed(error.localizedDescription) }
            }
        }
    }

    func stopScan() {
        scanTask?.cancel()
        scanTask = nil
        scanState = .idle
    }

    func setSelected(_ url: URL, _ isSelected: Bool) {
        if isSelected {
            selectedURLs.insert(url)
        } else {
            selectedURLs.remove(url)
        }
    }

    var allSelected: Bool {
        !items.isEmpty && items.allSatisfy { selectedURLs.contains($0.url) }
    }

    var selectionCount: Int {
        selectedURLs.count
    }

    func selectAll() {
        for item in items {
            selectedURLs.insert(item.url)
        }
    }

    func deselectAll() {
        selectedURLs.removeAll()
    }

    func toggleSelectAll() {
        if allSelected {
            deselectAll()
        } else {
            selectAll()
        }
    }

    func analyzeTopItems(limit: Int = 10) {
        guard !isAnalyzing else { return }

        let snapshot = settings.snapshot()
        guard let config = snapshot else {
            analyzeErrorMessage = "Invalid Base URL"
            return
        }

        // 成本控制：默认只分析 risk >= medium 的条目
        let candidates = itemsByURL.values
            .filter { ($0.ruleMatch?.rule.riskLevel ?? .high) != .low }
            .sorted { $0.sizeBytes > $1.sizeBytes }
            .prefix(limit)

        let targets = Array(candidates)
        guard !targets.isEmpty else { return }

        isAnalyzing = true
        analyzedCount = 0
        analyzeErrorMessage = nil

        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }

            await self.aiAnalyzer.updateConfiguration(config)
            let profile = await MainActor.run { self.buildDeveloperProfile() }
            let category = await MainActor.run { self.selectedCategory }

            await withTaskGroup(of: (URL, Result<AIAnalysis, Error>).self) { group in
                for item in targets {
                    let ctx = AnalysisContext(
                        path: item.url.path,
                        isDirectory: item.isDirectory,
                        sizeBytes: item.sizeBytes,
                        matchedRuleId: item.ruleMatch?.rule.id,
                        matchedRuleName: item.ruleMatch?.rule.name,
                        riskLevel: item.ruleMatch?.rule.riskLevel,
                        isActiveProject: item.ruleMatch?.isActiveProject
                    )
                    group.addTask {
                        do {
                            let analysis = try await self.aiAnalyzer.analyze(
                                context: ctx,
                                config: config,
                                category: category,
                                developerProfile: profile
                            )
                            return (item.url, .success(analysis))
                        } catch {
                            return (item.url, .failure(error))
                        }
                    }
                }

                for await (url, result) in group {
                    await MainActor.run {
                        self.analyzedCount += 1
                        if case .success(let analysis) = result, var existing = self.itemsByURL[url] {
                            existing.aiAnalysis = analysis
                            self.itemsByURL[url] = existing
                        } else if case .failure(let err) = result {
                            self.analyzeErrorMessage = err.localizedDescription
                        }

                        self.applySortAndFilter()
                    }
                }
            }

            await MainActor.run { self.isAnalyzing = false }
        }
    }

    func trashSelected() {
        let targets: [CandidateItem] = selectedURLs.compactMap { itemsByURL[$0] }
        guard !targets.isEmpty else { return }

        let dryRun = settings.dryRun
        let categoryId = selectedCategory.id
        let sessionId = currentSession?.id ?? UUID()
        lastTrashSummary = nil

        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let records = await self.trashManager.trash(items: targets, dryRun: dryRun)

            // 统计记录 (仅非dry-run)
            if !dryRun {
                let successRecords = records.filter { $0.success }

                // 规则分布统计
                var ruleBreakdown: [String: (name: String, count: Int, bytes: Int64)] = [:]
                for record in successRecords {
                    if let ruleId = record.matchedRuleId {
                        let existing = ruleBreakdown[ruleId] ?? (name: ruleId, count: 0, bytes: 0)
                        ruleBreakdown[ruleId] = (existing.name, existing.count + 1, existing.bytes + record.sizeBytes)
                    }
                }

                let stats = CleanupStatistics(
                    sessionId: sessionId,
                    timestamp: Date(),
                    categoryId: categoryId,
                    totalItemsTrashed: successRecords.count,
                    totalBytesFreed: successRecords.reduce(0) { $0 + $1.sizeBytes },
                    successfulOperations: successRecords.count,
                    failedOperations: records.count - successRecords.count,
                    byRuleOnly: successRecords.filter { $0.aiRecommendedAction == nil }.count,
                    byAIRecommendation: successRecords.filter { $0.aiRecommendedAction != nil }.count,
                    byManualSelection: 0
                )

                await self.statisticsManager.recordCleanup(
                    stats,
                    ruleBreakdown: ruleBreakdown.map { ($0.key, $0.value.name, $0.value.count, $0.value.bytes) }
                )
            }

            await MainActor.run {
                let ok = records.filter { $0.success }.count
                let fail = records.count - ok
                self.lastTrashSummary = dryRun
                    ? "Dry run: would trash \(ok), failed \(fail)"
                    : "Trashed \(ok), failed \(fail)"

                if !dryRun {
                    for r in records where r.success {
                        self.itemsByURL.removeValue(forKey: URL(fileURLWithPath: r.originalPath))
                        self.selectedURLs.remove(URL(fileURLWithPath: r.originalPath))
                    }
                    self.applySortAndFilter()
                }
            }
        }
    }

    func undoLastTrash() {
        lastTrashSummary = nil
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let records = await self.trashManager.undoLastBatch()
            await MainActor.run {
                let ok = records.filter { $0.success }.count
                let fail = records.count - ok
                self.lastTrashSummary = "Undo: restored \(ok), failed \(fail)"
            }
        }
    }
}

private func riskOrder(_ risk: RiskLevel?) -> Int {
    switch risk {
    case .low: return 0
    case .medium: return 1
    case .high: return 2
    case nil: return 3
    }
}

