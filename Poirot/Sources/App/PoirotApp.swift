import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // The selected theme drives the window appearance (dark theme -> dark chrome). Adaptive
        // themes return nil and follow the system.
        NSApp.appearance = ColorThemeStorage.current.appearance
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
    private var memorySources = MemorySourcesStore()
    @AppStorage("showMenuBarIcon")
    private var showMenuBarIcon = true
    @Environment(\.openWindow)
    private var openWindow
    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(appState)
                .environment(memorySources)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Poirot") {
                    openWindow(id: "about")
                }
                .help("Open the About window")

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
                .help("Check for updates")
            }
            CommandGroup(after: .textFormatting) {
                Button("Increase Font Size") { appState.increaseFontScale() }
                    .keyboardShortcut("+", modifiers: .command)
                    .help("Increase font size")
                Button("Decrease Font Size") { appState.decreaseFontScale() }
                    .keyboardShortcut("-", modifiers: .command)
                    .help("Decrease font size")
                Button("Reset Font Size") { appState.resetFontScale() }
                    .keyboardShortcut("0", modifiers: .command)
                    .help("Reset font size")
            }
            CommandGroup(replacing: .help) {
                Button("Poirot Help") {
                    openWindow(id: "help")
                }
                .keyboardShortcut("?", modifiers: .command)
                .help("Open Poirot Help")

                Button("Keyboard Shortcuts") {
                    appState.isShortcutHelpPresented = true
                }
                .help("Show keyboard shortcuts")
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
                .environment(memorySources)
        }

        MenuBarExtra("Poirot", image: "MenuBarIcon", isInserted: $showMenuBarIcon) {
            MenuBarView()
                .environment(appState)
        }
        .menuBarExtraStyle(.window)
    }
}
