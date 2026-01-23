import AppKit
import Foundation

#if canImport(Sparkle)
import Sparkle
#endif

@MainActor
final class UpdateManager: ObservableObject {
#if canImport(Sparkle)
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
#endif

    func checkForUpdates() {
#if canImport(Sparkle)
        updaterController.checkForUpdates(nil)
#else
        let alert = NSAlert()
        alert.messageText = "Sparkle 未集成"
        alert.informativeText = "当前工程未添加 Sparkle 依赖。请在 Xcode 中通过 Swift Package Manager 添加 Sparkle 后再启用自动更新。"
        alert.addButton(withTitle: "OK")
        alert.runModal()
#endif
    }
}

