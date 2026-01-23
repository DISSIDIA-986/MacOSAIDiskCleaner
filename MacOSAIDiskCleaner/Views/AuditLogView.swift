import SwiftUI
import AppKit

struct AuditLogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var records: [TrashRecord] = []
    @State private var logFileURL: URL?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Audit Log")
                    .font(.headline)
                Spacer()
                Button("Reveal Log File") { revealLogFile() }
                    .disabled(logFileURL == nil)
                Button("Copy (JSONL)") { copyRecentAsJSONL() }
                    .disabled(records.isEmpty)
                Button("Close") { dismiss() }
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(records) { rec in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(rec.success ? "OK" : "FAIL")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(rec.success ? .green : .red)
                            Text(rec.timestamp.formatted(date: .numeric, time: .standard))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: rec.sizeBytes, countStyle: .file))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Text(rec.originalPath)
                            .font(.caption)
                            .lineLimit(2)
                        if let msg = rec.errorMessage, !msg.isEmpty {
                            Text(msg)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .frame(width: 760, height: 520)
        .task { await reload() }
    }

    private func reload() async {
        isLoading = true
        let tm = TrashManager()
        let recent = await tm.recentAudit(limit: 200)
        records = recent
        logFileURL = await tm.auditLogFileURL()
        isLoading = false
    }

    private func revealLogFile() {
        guard let url = logFileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func copyRecentAsJSONL() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let lines: [String] = records.compactMap { rec in
            guard let data = try? encoder.encode(rec),
                  let str = String(data: data, encoding: .utf8) else { return nil }
            return str
        }
        let text = lines.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

