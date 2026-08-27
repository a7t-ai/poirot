import SwiftUI

// MARK: - Native Toolbar Actions (placed in ContentView toolbar)

struct ConfigToolbarActions: View {
    @Environment(AppState.self)
    private var appState

    @AppStorage("textEditor")
    private var textEditor = PreferredEditor.vscode.rawValue

    @State
    private var openTapped = false
    @State
    private var copyNameTapped = false
    @State
    private var copyContentTapped = false
    @State
    private var revealTapped = false
    @State
    private var formatTapped = false

    private var editor: PreferredEditor {
        PreferredEditor(rawValue: textEditor) ?? .vscode
    }

    var body: some View {
        if appState.activeConfigDetail != nil {
            @Bindable
            var state = appState

            Button {
                state.configDetailFormatted.toggle()
                formatTapped = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { formatTapped = false }
            } label: {
                Image(systemName: state.configDetailFormatted
                    ? "chevron.left.forwardslash.chevron.right"
                    : "textformat")
                    .contentTransition(.symbolEffect(.replace))
            }
            .help(state.configDetailFormatted ? "Show Raw" : "Show Formatted")
            .animation(.easeInOut(duration: 0.2), value: formatTapped)
        }

        if let info = appState.activeConfigDetail {
            Button {
                EditorLauncher.open(filePath: info.filePath, editor: editor)
                openTapped = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { openTapped = false }
            } label: {
                Image(systemName: openTapped ? "checkmark" : "pencil.and.outline")
                    .contentTransition(.symbolEffect(.replace))
            }
            .help("Open in \(editor.displayName)")
            .animation(.easeInOut(duration: 0.2), value: openTapped)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(info.name, forType: .string)
                appState.showToast("Copied `\(info.name)`")
                copyNameTapped = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copyNameTapped = false }
            } label: {
                Image(systemName: copyNameTapped ? "checkmark" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))
            }
            .help("Copy Name")
            .animation(.easeInOut(duration: 0.2), value: copyNameTapped)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(info.markdownContent, forType: .string)
                appState.showToast("Copied content to clipboard")
                copyContentTapped = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copyContentTapped = false }
            } label: {
                Image(systemName: copyContentTapped ? "checkmark" : "text.page")
                    .contentTransition(.symbolEffect(.replace))
            }
            .help("Copy Content")
            .animation(.easeInOut(duration: 0.2), value: copyContentTapped)

            Button {
                let url = URL(fileURLWithPath: info.filePath)
                NSWorkspace.shared.activateFileViewerSelecting([url])
                revealTapped = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { revealTapped = false }
            } label: {
                Image(systemName: revealTapped ? "checkmark" : "folder")
                    .contentTransition(.symbolEffect(.replace))
            }
            .help("Show in Finder")
            .animation(.easeInOut(duration: 0.2), value: revealTapped)
        }
    }
}

struct ConfigToolbarDelete: View {
    @State
    private var showDeleteConfirmation = false

    @Environment(AppState.self)
    private var appState

    var body: some View {
        if let info = appState.activeConfigDetail {
            Button {
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
            }
            .help("Delete")
            .confirmationDialog(
                "Delete \(info.name)?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if ClaudeConfigLoader.deleteConfigFile(at: info.filePath) {
                        let navID = appState.selectedNav.id
                        if let current = appState.sidebarCounts[navID], current > 0 {
                            appState.sidebarCounts[navID] = current - 1
                        }
                        appState.showToast("Deleted \(info.name)", icon: "trash", style: .info)
                        appState.activeConfigDetail = nil
                    }
                }
            } message: {
                Text("This will permanently delete the file. This action cannot be undone.")
            }
        }
    }
}

struct ConfigToolbarClose: View {
    @Environment(AppState.self)
    private var appState

    var body: some View {
        Button {
            appState.activeConfigDetail = nil
        } label: {
            Image(systemName: "xmark")
        }
        .help("Close")
    }
}
