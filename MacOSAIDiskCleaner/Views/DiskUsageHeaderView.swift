import SwiftUI

struct DiskUsageHeaderView: View {
    var body: some View {
        let info = DiskUsage.read()
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Disk")
                    .font(.headline)
                Spacer()
                Text(info.summaryText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: info.usedFraction)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct DiskUsage {
    let totalBytes: Int64
    let availableBytes: Int64

    var usedBytes: Int64 { max(0, totalBytes - availableBytes) }
    var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }

    var summaryText: String {
        let used = ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        return "\(used) used / \(total)"
    }

    static func read() -> DiskUsage {
        let root = URL(fileURLWithPath: "/")
        let values = try? root.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
        let total = Int64(values?.volumeTotalCapacity ?? 0)
        let avail = Int64(values?.volumeAvailableCapacity ?? 0)
        return DiskUsage(totalBytes: total, availableBytes: avail)
    }
}

