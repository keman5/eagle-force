import SwiftUI
import Observation
import UIKit

@main
struct EagleForceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = PilotStore()

    var body: some Scene {
        WindowGroup {
            CampaignView(store: store)
                .preferredColorScheme(.dark)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientation: UIInterfaceOrientationMask = .portrait
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask { Self.orientation }

    static func rotate(for mission: Mission?) {
        orientation = .portrait
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
    }
}

@MainActor @Observable
final class PilotStore {
    var pilot = PilotProgress()
    var error: String?
    var loadFailed = false
    @ObservationIgnored private let save: SaveFile

    init() {
        let root = URL.applicationSupportDirectory.appending(path: "EagleForce")
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            save = SaveFile(url: URL.temporaryDirectory.appending(path: "EagleForceUITests-\(UUID().uuidString)/pilot.json"))
        } else { save = SaveFile(url: root.appending(path: "pilot.json")) }
        #else
        save = SaveFile(url: root.appending(path: "pilot.json"))
        #endif
        reload()
    }

    func reload() {
        do { pilot = try save.load(); loadFailed = false; error = nil }
        catch { loadFailed = true; self.error = "无法读取飞行档案，原存档已保留。请重试读取。\n\(error.localizedDescription)" }
    }

    var previewUnlocked: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-unlock-missions")
        #else
        false
        #endif
    }

    func unlocked(_ id: Int) -> Bool { !loadFailed && (pilot.unlocked(id) || previewUnlocked) }

    func purchase(_ upgrade: Upgrade) {
        var next = pilot
        guard !loadFailed, next.purchase(upgrade) else { return }
        commit(next)
    }

    func set(_ keyPath: WritableKeyPath<PilotProgress, Bool>, to value: Bool) {
        guard !loadFailed else { return }
        var next = pilot; next[keyPath: keyPath] = value; commit(next)
    }

    func settle(_ result: SortieResult) -> Reward? {
        guard !loadFailed else { return nil }
        var next = pilot
        #if DEBUG
        if previewUnlocked {
            for id in 1..<result.missionID { next.medals[id, default: []].insert("clear") }
        }
        #endif
        guard let reward = next.settle(result) else { return nil }
        return commit(next) ? reward : nil
    }

    @discardableResult private func commit(_ next: PilotProgress) -> Bool {
        do { try save.write(next); pilot = next; return true }
        catch { self.error = "档案保存失败，奖励或升级尚未入账，请重试。\n\(error.localizedDescription)"; return false }
    }
}
