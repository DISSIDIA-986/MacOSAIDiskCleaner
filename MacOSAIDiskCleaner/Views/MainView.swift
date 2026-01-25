import SwiftUI

struct MainView: View {
    @ObservedObject var viewModel: DiskCleanerViewModel
    @State private var showSettings = false

    var body: some View {
        Group {
            if viewModel.permissionManager.fullDiskAccessStatus != .granted {
                PermissionOnboardingView(permissionManager: viewModel.permissionManager)
            } else {
                if #available(macOS 13.0, *) {
                    NavigationSplitView {
                        sidebarSplitView
                    } detail: {
                        detailView
                    }
                } else {
                    NavigationView {
                        sidebarLegacy
                        detailView
                    }
                }
            }
        }
        .onAppear {
            viewModel.onAppear()
            Task { await viewModel.loadCategories() }
        }
    }

    @available(macOS 13.0, *)
    @ViewBuilder
    private var sidebarSplitView: some View {
        List(selection: $viewModel.selectedCategory) {
            Section("Categories") {
                ForEach(viewModel.availableCategories) { category in
                    Label(category.name, systemImage: category.icon)
                        .tag(category)
                        .help(category.description)
                }
            }

            Section {
                NavigationLink {
                    StatisticsDashboardView()
                } label: {
                    Label("Statistics", systemImage: "chart.bar.fill")
                }

                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gear")
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minWidth: 220)
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel.settings)
                .frame(minWidth: 540, minHeight: 400)
        }
    }

    @ViewBuilder
    private var sidebarLegacy: some View {
        List {
            Section(header: Text("Categories")) {
                ForEach(viewModel.availableCategories) { category in
                    Button {
                        viewModel.selectedCategory = category
                    } label: {
                        HStack {
                            Label(category.name, systemImage: category.icon)
                            Spacer()
                            if viewModel.selectedCategory.id == category.id {
                                Text("✓").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                NavigationLink(destination: StatisticsDashboardView()) {
                    Label("Statistics", systemImage: "chart.bar.fill")
                }

                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gear")
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minWidth: 220)
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel.settings)
                .frame(minWidth: 540, minHeight: 400)
        }
        .task {
            await viewModel.loadCategories()
        }
    }

    @ViewBuilder
    private var detailView: some View {
        VStack(spacing: 12) {
            DiskUsageHeaderView()

            HStack(spacing: 12) {
                Button("Scan") { viewModel.startScan() }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityLabel("Start scanning for files to clean")
                Button("Stop") { viewModel.stopScan() }
                    .disabled(viewModel.scanState != .scanning)
                    .accessibilityLabel("Stop current scan")

                Divider().frame(height: 20)

                Toggle("Select All", isOn: Binding(
                    get: { viewModel.allSelected },
                    set: { _ in viewModel.toggleSelectAll() }
                ))
                .toggleStyle(.checkbox)
                .disabled(viewModel.items.isEmpty)

                Text("\(viewModel.selectionCount) selected")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 80, alignment: .leading)

                Divider().frame(height: 20)

                Picker("Sort", selection: $viewModel.sortOrder) {
                    ForEach(DiskCleanerViewModel.SortOrder.allCases) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .frame(width: 150)
                .onChange(of: viewModel.sortOrder) { _ in
                    viewModel.applySortAndFilter()
                }

                Picker("Filter", selection: $viewModel.riskFilter) {
                    ForEach(DiskCleanerViewModel.RiskFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .frame(width: 120)
                .onChange(of: viewModel.riskFilter) { _ in
                    viewModel.applySortAndFilter()
                }

                Divider().frame(height: 20)

                Button("Analyze top 10") { viewModel.analyzeTopItems(limit: 10) }
                    .disabled(viewModel.isAnalyzing || viewModel.items.isEmpty)
                    .accessibilityLabel("Analyze top 10 items with AI")

                Button("Trash selected") { viewModel.trashSelected() }
                    .disabled(viewModel.selectedURLs.isEmpty)
                    .accessibilityLabel("Move selected items to trash")

                Button("Undo last") { viewModel.undoLastTrash() }
                    .accessibilityLabel("Undo last trash operation")

                Spacer()

                Text(statusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if viewModel.settings.dryRun {
                HStack {
                    Image(systemName: "shield.fill")
                        .foregroundStyle(.blue)
                    Text("Dry Run Mode - No files will be deleted")
                        .font(.footnote)
                        .foregroundStyle(.blue)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(.blue.opacity(0.1))
            }

            if viewModel.isAnalyzing {
                HStack {
                    ProgressView()
                    Text("Analyzing… \(viewModel.analyzedCount)/10")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else if let msg = viewModel.analyzeErrorMessage {
                Text("AI error: \(msg)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if let msg = viewModel.lastTrashSummary {
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if viewModel.items.isEmpty && viewModel.scanState == .finished {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("No large items found")
                        .font(.headline)
                    Text("Try scanning a different category")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.items.isEmpty && viewModel.scanState == .idle {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Click Scan to start")
                        .font(.headline)
                    Text("Select a category from the sidebar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.items) { item in
                    HStack {
                        riskIcon(for: item.effectiveRiskLevel)

                        Toggle("", isOn: Binding(
                            get: { viewModel.selectedURLs.contains(item.url) },
                            set: { viewModel.setSelected(item.url, $0) }
                        ))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .accessibilityLabel("Select \(item.name) for cleanup")

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.body)
                            Text(item.url.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            if let rule = item.ruleMatch?.rule {
                                Text("Rule: \(rule.name)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let ai = item.aiAnalysis {
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 4) {
                                        Text("AI:")
                                            .fontWeight(.medium)
                                        Text(ai.recommendedAction.rawValue.capitalized)
                                            .foregroundStyle(ai.recommendedAction == .delete ? .red : (ai.recommendedAction == .keep ? .green : .orange))
                                        Text("(\(Int(ai.confidence * 100))%)")
                                            .foregroundStyle(.secondary)
                                    }
                                    .font(.caption2)

                                    if !ai.summary.isEmpty {
                                        Text(ai.summary)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }

                                    if !ai.reasons.isEmpty {
                                        Text("• " + ai.reasons.prefix(2).joined(separator: " • "))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }

                                    if !ai.warnings.isEmpty {
                                        HStack(spacing: 2) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundStyle(.orange)
                                            Text(ai.warnings.first ?? "")
                                                .foregroundStyle(.orange)
                                        }
                                        .font(.caption2)
                                        .lineLimit(1)
                                    }
                                }
                            }
                        }
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file))
                            .font(.body.monospacedDigit())
                    }
                }
            }
        }
        .padding()
    }

    private var statusText: String {
        switch viewModel.scanState {
        case .idle:
            return "Idle"
        case .scanning:
            let size = ByteCountFormatter.string(fromByteCount: viewModel.scannedBytes, countStyle: .file)
            let percent: String
            if viewModel.estimatedTotalFiles > 0 {
                let pct = Int((Double(viewModel.visitedFileCount) / Double(viewModel.estimatedTotalFiles)) * 100)
                percent = " (\(pct)%)"
            } else {
                percent = ""
            }
            return "Scanning… visited: \(viewModel.visitedFileCount)\(percent), files: \(viewModel.scannedFileCount), size: \(size)"
        case .finished:
            return "Finished"
        case .failed(let msg):
            return "Failed: \(msg)"
        }
    }

    @ViewBuilder
    private func riskIcon(for risk: RiskLevel?) -> some View {
        switch risk {
        case .low:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .medium:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
        case .high:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case nil:
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
        }
    }
}

