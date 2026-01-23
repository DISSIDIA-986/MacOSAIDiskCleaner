import Foundation

struct ScannedItem: Identifiable, Hashable, Sendable {
    let id: URL
    let url: URL
    let isDirectory: Bool
    let sizeBytes: Int64

    var name: String { url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent }
}

