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

            UsageSettingsView()
                .tabItem {
                    Label("Usage", systemImage: "gauge.with.dots.needle.bottom.50percent")
                }

            MenuBarSettingsView()
                .tabItem {
                    Label("Menu Bar", systemImage: "menubar.rectangle")
                }
        }
        .frame(width: 560, height: 360)
    }
}

// MARK: - Usage

private struct UsageSettingsView: View {
    @Environment(UsageStore.self)
    private var usageStore
    @Environment(\.provider)
    private var provider

    private var intervalBinding: Binding<UsageRefreshInterval> {
        Binding(
            get: { usageStore.refreshInterval },
            set: { usageStore.setRefreshInterval($0) }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if provider.supports(.usage) {
                settingsRow {
                    Text("Auto-Refresh:")
                } control: {
                    Picker("", selection: intervalBinding) {
                        ForEach(UsageRefreshInterval.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }

                settingsRow {
                    Text("")
                } control: {
                    Text(usageStore.refreshInterval == .manual
                        ? "Usage updates only when you tap refresh."
                        : "Poirot re-fetches your usage \(usageStore.refreshInterval.label.lowercased()) while it's open.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Usage limits aren't available for this provider.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Spacer()
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 32)
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
    @AppStorage("appearanceMode")
    private var appearanceMode = AppearanceMode.auto.rawValue
    @AppStorage("accentColor")
    private var accentColorRaw = AccentColor.golden.rawValue
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
            }
        )
    }

    private var appearanceModeBinding: Binding<AppearanceMode> {
        Binding(
            get: { AppearanceMode(rawValue: appearanceMode) ?? .auto },
            set: { newValue in
                appearanceMode = newValue.rawValue
                NSApp.appearance = newValue.appearance
            }
        )
    }

    private var accentColorBinding: Binding<AccentColor> {
        Binding(
            get: { AccentColor(rawValue: accentColorRaw) ?? .golden },
            set: { newValue in
                accentColorRaw = newValue.rawValue
                AccentColorStorage.current = newValue
            }
        )
    }

    var body: some View {
        @Bindable
        var appState = appState

        VStack(spacing: 0) {
            settingsRow(alignment: .top) {
                Text("Appearance:")
            } control: {
                AppearancePicker(selection: appearanceModeBinding)
            }

            settingsDivider

            settingsRow(alignment: .top) {
                Text("Theme:")
            } control: {
                ThemePicker(selection: colorThemeBinding)
            }

            settingsDivider

            settingsRow {
                Text("Accent Color:")
            } control: {
                AccentColorPicker(selection: accentColorBinding)
            }

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

            Spacer()
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 32)
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
