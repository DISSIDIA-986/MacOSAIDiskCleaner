import SwiftUI

struct MainView: View {
    @ObservedObject var viewModel: DiskCleanerViewModel

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
        .onAppear { viewModel.onAppear() }
    }

    @available(macOS 13.0, *)
    @ViewBuilder
    private var sidebarSplitView: some View {
        List(selection: $viewModel.selectedCategory) {
            Section("Categories") {
                ForEach(DiskCleanerViewModel.Category.allCases) { c in
                    Text(c.rawValue).tag(c)
                }
            }
        }
        .frame(minWidth: 220)
    }

    @ViewBuilder
    private var sidebarLegacy: some View {
        List {
            Section(header: Text("Categories")) {
                ForEach(DiskCleanerViewModel.Category.allCases) { c in
                    Button {
                        viewModel.selectedCategory = c
                    } label: {
                        HStack {
                            Text(c.rawValue)
                            Spacer()
                            if viewModel.selectedCategory == c {
                                Text("✓").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(minWidth: 220)
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

            List(viewModel.items) { item in
                HStack {
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
                            Text("Rule: \(rule.name) (\(rule.riskLevel.rawValue))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let ai = item.aiAnalysis {
                            Text("AI: \(ai.recommendedAction.rawValue) (\(ai.riskLevel.rawValue), \(Int(ai.confidence * 100))%)")
                                .font(.caption2)
                        }
                    }
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file))
                        .font(.body.monospacedDigit())
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
}

