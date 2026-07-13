import SwiftUI

struct ConfigProjectPicker: View {
    @Environment(AppState.self)
    private var appState

    var body: some View {
        HStack(spacing: PoirotTheme.Spacing.sm) {
            Image(systemName: "folder.fill")
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(
                    appState.configProjectPath != nil
                        ? PoirotTheme.Colors.green
                        : PoirotTheme.Colors.textTertiary
                )

            if let name = appState.configProjectName {
                Text(name)
                    .font(PoirotTheme.Typography.caption)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)
                    .lineLimit(1)

                Button {
                    appState.configProjectPath = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(PoirotTheme.Typography.caption)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Clear project")
            } else {
                Text("No project selected")
                    .font(PoirotTheme.Typography.caption)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            }

            Spacer()

            Button {
                browseForProject()
            } label: {
                Text("Browse\u{2026}")
                    .font(PoirotTheme.Typography.caption)
                    .foregroundStyle(PoirotTheme.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Choose project folder")
        }
        .padding(.horizontal, PoirotTheme.Spacing.md)
        .padding(.vertical, PoirotTheme.Spacing.sm)
    }

    private func browseForProject() {
        let panel = NSOpenPanel()
        panel.title = "Select Project Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            appState.configProjectPath = path

            let claudeDir = url.appendingPathComponent(".claude")
            var isDir: ObjCBool = false
            if !FileManager.default.fileExists(atPath: claudeDir.path, isDirectory: &isDir) || !isDir.boolValue {
                appState.showToast(
                    "No .claude/ directory found in **\(url.lastPathComponent)**",
                    icon: "exclamationmark.triangle.fill",
                    style: .info
                )
            }
        }
    }
}
