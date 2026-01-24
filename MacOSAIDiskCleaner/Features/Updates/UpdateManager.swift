import AppKit
import Foundation

#if canImport(Sparkle)
import Sparkle
#endif

/// Manages Sparkle auto-update integration for MacOSAIDiskCleaner
class UpdateManager: NSObject, ObservableObject {
    @Published var canCheckForUpdates = false
    @Published var lastUpdateCheck: Date?
    
    // Sparkle updater controller
    private var updaterController: SPUStandardUpdaterController?
    
    override init() {
        super.init()
        #if canImport(Sparkle)
        // Initialize Sparkle
        // We use the standard updater controller which provides a standard UI
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
        
        canCheckForUpdates = true
        #endif
    }
    
    func checkForUpdates() {
        #if canImport(Sparkle)
        updaterController?.updater.checkForUpdates()
        #else
        print("Sparkle not available")
        #endif
    }
}

// MARK: - Sparkle Delegate
#if canImport(Sparkle)
extension UpdateManager: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        print("Found update: \(item.displayVersionString)")
    }
    
    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        print("No update found. Error: \(String(describing: error))")
    }
    
    // Optional: Log when update finishes loading
    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        print("Finished loading appcast with \(appcast.items.count) items")
    }
}
#endif

