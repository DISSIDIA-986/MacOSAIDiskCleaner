import Foundation

enum DiskCleanerError: LocalizedError {
    case permissionDenied(String)
    case scanCancelled
    case fileInUse(URL)
    case trashFailed(URL, Error)
    case aiRequestFailed(Error)
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied(let path):
            return "Access denied to path: \(path). Please grant Full Disk Access."
        case .scanCancelled:
            return "Disk scan was cancelled by the user."
        case .fileInUse(let url):
            return "File is currently in use: \(url.lastPathComponent)"
        case .trashFailed(let url, let error):
            return "Failed to move \(url.lastPathComponent) to Trash: \(error.localizedDescription)"
        case .aiRequestFailed(let error):
            return "AI Analysis failed: \(error.localizedDescription)"
        case .networkUnavailable:
            return "Network connection unavailable. AI features disabled."
        }
    }
}
