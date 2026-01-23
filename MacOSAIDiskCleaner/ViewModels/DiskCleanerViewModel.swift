import Foundation

@MainActor
final class DiskCleanerViewModel: ObservableObject {
    enum Category: String, CaseIterable, Identifiable {
        case caches = "Caches"
        case developer = "Developer"
        case home = "Home"

        var id: String { rawValue }
    }

    enum ScanState: Equatable {
        case idle
        case scanning
        case finished
        case failed(String)
    }

    @Published var selectedCategory: Category = .caches
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

    private let scanner = FileScanner()
    private var ruleMatcher: RuleMatcher {
        RuleMatcher(rules: BuiltInRules.all, options: settings.ruleMatcherOptions())
    }
    private let aiAnalyzer = AIAnalyzer()
    private let trashManager = TrashManager()
    private var scanTask: Task<Void, Never>?
    private var itemsByURL: [URL: CandidateItem] = [:]

    func onAppear() {
        permissionManager.refresh()
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

        let root = scanRootURL(for: selectedCategory)

        // Quick estimate for progress percentage
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let estimate = await self.scanner.estimateTotalFiles(root: root)
            await MainActor.run {
                self.estimatedTotalFiles = estimate
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
                        aiAnalysis: existing?.aiAnalysis
                    )
                    self.itemsByURL[s.url] = candidate
                }

                let sorted = self.itemsByURL.values.sorted {
                    let l = riskOrder($0.effectiveRiskLevel)
                    let r = riskOrder($1.effectiveRiskLevel)
                    if l != r { return l < r } // low risk first
                    return $0.sizeBytes > $1.sizeBytes
                }
                self.items = Array(sorted.prefix(500))
            }
            await updater.start()

            do {
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
                await updater.flushIfNeeded()
                await MainActor.run { self.scanState = .finished }
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
                            let analysis = try await self.aiAnalyzer.analyze(context: ctx, config: config)
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

                        let sorted = self.itemsByURL.values.sorted {
                            let l = riskOrder($0.effectiveRiskLevel)
                            let r = riskOrder($1.effectiveRiskLevel)
                            if l != r { return l < r }
                            return $0.sizeBytes > $1.sizeBytes
                        }
                        self.items = Array(sorted.prefix(500))
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
        lastTrashSummary = nil

        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let records = await self.trashManager.trash(items: targets, dryRun: dryRun)

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
                    let sorted = self.itemsByURL.values.sorted {
                        let l = riskOrder($0.effectiveRiskLevel)
                        let r = riskOrder($1.effectiveRiskLevel)
                        if l != r { return l < r }
                        return $0.sizeBytes > $1.sizeBytes
                    }
                    self.items = Array(sorted.prefix(500))
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

    private func scanRootURL(for category: Category) -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch category {
        case .caches:
            return home.appendingPathComponent("Library/Caches", isDirectory: true)
        case .developer:
            return home.appendingPathComponent("Library/Developer", isDirectory: true)
        case .home:
            return home
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

