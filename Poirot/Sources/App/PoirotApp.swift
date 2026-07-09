import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let mode = AppearanceMode(rawValue: UserDefaults.standard.string(forKey: "appearanceMode") ?? "") ?? .auto
        NSApp.appearance = mode.appearance
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: "New Window", action: #selector(newWindow(_:)), keyEquivalent: "")
        return menu
    }

    @objc
    private func newWindow(_ sender: Any?) {
        NSApp.activate()
        NSApp.sendAction(#selector(NSResponder.newWindowForTab(_:)), to: nil, from: nil)
    }
}

@main
struct PoirotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate
    @State
    private var appState = AppState()
    @State
    private var usageStore = UsageStore()
    @AppStorage("showMenuBarIcon")
    private var showMenuBarIcon = true
    @Environment(\.openWindow)
    private var openWindow
    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(appState)
                .environment(usageStore)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Poirot") {
                    openWindow(id: "about")
                }

                Divider()

                Button("Check for Updates…") {
                    Task {
                        appState.showToast(
                            "Checking for updates…",
                            icon: "arrow.triangle.2.circlepath",
                            style: .info,
                            animateIcon: true
                        )
                        if let release = await UpdateChecker.checkForUpdate() {
                            appState.showToast(
                                "New version available: **\(release.tagName)**\nTap to download from GitHub",
                                icon: "arrow.down.circle.fill",
                                style: .info,
                                url: URL(string: release.htmlURL)
                            )
                        } else {
                            appState.showToast(
                                "You're up to date! Running **v\(Bundle.main.appVersion)**",
                                icon: "checkmark.circle.fill",
                                style: .success
                            )
                        }
                    }
                }
            }
            CommandGroup(after: .textFormatting) {
                Button("Increase Font Size") { appState.increaseFontScale() }
                    .keyboardShortcut("+", modifiers: .command)
                Button("Decrease Font Size") { appState.decreaseFontScale() }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Reset Font Size") { appState.resetFontScale() }
                    .keyboardShortcut("0", modifiers: .command)
            }
            CommandGroup(replacing: .help) {
                Button("Poirot Help") {
                    openWindow(id: "help")
                }
                .keyboardShortcut("?", modifiers: .command)

                Button("Keyboard Shortcuts") {
                    appState.isShortcutHelpPresented = true
                }
            }
        }

        Window("About Poirot", id: "about") {
            AboutView()
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)

        Window("Poirot Help", id: "help") {
            HelpView()
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environment(appState)
                .environment(usageStore)
        }

        MenuBarExtra("Poirot", image: "MenuBarIcon", isInserted: $showMenuBarIcon) {
            MenuBarView()
                .environment(appState)
                .environment(usageStore)
        }
        .menuBarExtraStyle(.window)
    }
}
