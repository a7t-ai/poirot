import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            ViewerSettingsView()
                .tabItem {
                    Label("Viewer", systemImage: "eye")
                }

            MemorySettingsView()
                .tabItem {
                    Label("Memory", systemImage: "brain.head.profile")
                }

            MenuBarSettingsView()
                .tabItem {
                    Label("Menu Bar", systemImage: "menubar.rectangle")
                }
        }
        .frame(width: 620, height: 500)
    }
}

// MARK: - Memory

private struct MemorySettingsView: View {
    @Environment(MemorySourcesStore.self)
    private var memorySources
    @Environment(AppState.self)
    private var appState

    var body: some View {
        VStack(spacing: 0) {
            settingsRow(alignment: .top) {
                Text("Extra Folders:")
            } control: {
                VStack(alignment: .leading, spacing: 8) {
                    if memorySources.folders.isEmpty {
                        // swiftlint:disable:next line_length
                        Text("No extra folders yet. Add one to show its `.md` files in the Memory tab, alongside your project memory.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ForEach(memorySources.folders, id: \.self) { url in
                            HStack(spacing: 8) {
                                Image(systemName: "folder")
                                    .foregroundStyle(.secondary)
                                Text(url.path)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .help(url.path)
                                Spacer(minLength: 8)
                                Button {
                                    memorySources.remove(url)
                                    syncMemoryCount()
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Remove folder")
                            }
                        }
                    }

                    Button(action: addFolders) {
                        Label("Add Folder…", systemImage: "plus")
                    }
                }
                .frame(maxWidth: 340, alignment: .leading)
            }

            Spacer()
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 32)
    }

    private func addFolders() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        panel.message = "Choose folders whose Markdown files should appear in the Memory tab."
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { memorySources.add(url) }
        syncMemoryCount()
    }

    private func syncMemoryCount() {
        appState.sidebarCounts[NavigationItem.memory.id] = ClaudeConfigLoader.totalMemoryFileCount()
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    @Environment(\.provider)
    private var provider
    @AppStorage("textEditor")
    private var textEditor = PreferredEditor.vscode.rawValue
    @AppStorage("preferredTerminal")
    private var preferredTerminal = PreferredTerminal.terminal.rawValue
    @AppStorage("openTerminalOnBash")
    private var openTerminalOnBash = false
    @AppStorage("claudeCodePath")
    private var claudeCodePath = "/usr/local/bin/claude"

    var body: some View {
        VStack(spacing: 0) {
            settingsRow {
                Text("Default Editor:")
            } control: {
                Picker("", selection: $textEditor) {
                    ForEach(PreferredEditor.installedCases, id: \.rawValue) { editor in
                        Label {
                            Text(editor.displayName)
                        } icon: {
                            if let icon = editor.appIcon {
                                Image(nsImage: icon)
                            }
                        }
                        .tag(editor.rawValue)
                    }
                }
                .labelsHidden()
            }

            settingsRow {
                Text("Terminal Application:")
            } control: {
                Picker("", selection: $preferredTerminal) {
                    ForEach(PreferredTerminal.installedCases, id: \.rawValue) { terminal in
                        Label {
                            Text(terminal.displayName)
                        } icon: {
                            if let icon = terminal.appIcon {
                                Image(nsImage: icon)
                            }
                        }
                        .tag(terminal.rawValue)
                    }
                }
                .labelsHidden()
            }

            settingsRow {
                Text("Open Terminal Automatically:")
            } control: {
                Toggle("Open terminal when copying bash commands", isOn: $openTerminalOnBash)
                    .labelsHidden()
            }

            settingsRow {
                Text("\(provider.cliLabel):")
            } control: {
                HStack(spacing: 8) {
                    TextField("", text: $claudeCodePath)
                        .textFieldStyle(.roundedBorder)

                    Button("Browse\u{2026}") {
                        browseForCLI()
                    }
                    .help("Browse for the CLI executable")
                }
            }
            Spacer()
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 32)
    }

    private func browseForCLI() {
        let panel = NSOpenPanel()
        panel.title = "Select CLI Executable"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            claudeCodePath = url.path
        }
    }
}

// MARK: - Appearance

private struct AppearanceSettingsView: View {
    @Environment(AppState.self)
    private var appState
    @AppStorage("colorTheme")
    private var colorThemeRaw = ColorTheme.default.rawValue
    @AppStorage("showAnimations")
    private var showAnimations = true

    private var colorThemeBinding: Binding<ColorTheme> {
        Binding(
            get: { ColorTheme(rawValue: colorThemeRaw) ?? .default },
            set: { newValue in
                colorThemeRaw = newValue.rawValue
                ColorThemeStorage.current = newValue
                // The theme drives the window appearance (dark theme -> dark chrome).
                NSApp.appearance = newValue.appearance
            }
        )
    }

    var body: some View {
        @Bindable
        var appState = appState

        ScrollView {
            VStack(spacing: 0) {
                // Theme is the single look control — it sets colors, accent, and light/dark chrome.
                // Shown full-width as a wrapping grid of every theme.
                VStack(alignment: .leading, spacing: 12) {
                    Text("Theme")
                    ThemePicker(selection: colorThemeBinding)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)

                settingsDivider

                settingsRow {
                    Text("Animations:")
                } control: {
                    Toggle("Message streaming animations", isOn: $showAnimations)
                        .labelsHidden()
                }

                settingsDivider

                settingsRow {
                    Text("Font Size:")
                } control: {
                    HStack(spacing: 8) {
                        Button { appState.decreaseFontScale() } label: {
                            Image(systemName: "minus")
                        }
                        .help("Decrease font size")
                        Text("\(Int(round(appState.fontScale * 100)))%")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .center)
                        Button { appState.increaseFontScale() } label: {
                            Image(systemName: "plus")
                        }
                        .help("Increase font size")
                        Button("Reset") { appState.resetFontScale() }
                            .help("Reset font size to 100%")
                            .disabled(appState.fontScale == 1.0)
                    }
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Viewer

private struct ViewerSettingsView: View {
    @AppStorage("wrapCodeLines")
    private var wrapCodeLines = true
    @AppStorage("autoExpandBlocks")
    private var autoExpandBlocks = true
    @AppStorage("parseMarkdownInResults")
    private var parseMarkdown = true

    var body: some View {
        VStack(spacing: 0) {
            settingsRow {
                Text("Wrap Lines Automatically:")
            } control: {
                Toggle("Wrap lines in code blocks", isOn: $wrapCodeLines)
                    .labelsHidden()
            }

            settingsRow {
                Text("Expand Blocks Automatically:")
            } control: {
                Toggle("Expand tool blocks automatically", isOn: $autoExpandBlocks)
                    .labelsHidden()
            }

            settingsRow {
                Text("Parse Markdown Automatically:")
            } control: {
                Toggle("Render markdown in tool results", isOn: $parseMarkdown)
                    .labelsHidden()
            }

            Spacer()
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 32)
    }
}

// MARK: - Menu Bar

private struct MenuBarSettingsView: View {
    @AppStorage("showMenuBarIcon")
    private var showMenuBarIcon = true

    @State
    private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(spacing: 0) {
            settingsRow {
                Text("Menu Bar Icon:")
            } control: {
                Toggle("Show Poirot in menu bar", isOn: $showMenuBarIcon)
                    .labelsHidden()
            }

            settingsRow {
                Text("Launch at Login:")
            } control: {
                Toggle("Start Poirot when you log in", isOn: $launchAtLogin)
                    .labelsHidden()
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            Spacer()
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 32)
    }
}

// MARK: - Settings Layout Helpers

private let settingsLabelWidth: CGFloat = 200

@MainActor
private func settingsRow(
    alignment: VerticalAlignment = .firstTextBaseline,
    @ViewBuilder label: () -> some View,
    @ViewBuilder control: () -> some View
) -> some View {
    HStack(alignment: alignment, spacing: 12) {
        label()
            .frame(width: settingsLabelWidth, alignment: .trailing)

        control()

        Spacer()
    }
    .padding(.vertical, 8)
}

@MainActor
private var settingsDivider: some View {
    Divider()
        .padding(.leading, settingsLabelWidth + 12)
        .padding(.vertical, 4)
}
