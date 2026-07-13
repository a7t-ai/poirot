import SwiftUI

// MARK: - Session Toolbar (matches ConfigLayoutToolbar pattern)

struct SessionToolbar: ToolbarContent {
    let session: Session

    @Environment(AppState.self)
    private var appState

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Spacer()
        }
        ToolbarItemGroup(placement: .primaryAction) {
            SessionToolbarFilterField()
            SessionToolbarActions(session: session)
            SessionToolbarFileHistory(session: session)
            SessionToolbarExport(session: session)
            SessionToolbarDebugLog(session: session)
            SessionToolbarExpandCollapse()
            SessionToolbarFilter()
            SessionToolbarDelete(session: session)
            SessionToolbarClose()
        }
    }
}

// MARK: - Filter Field (replaces search toggle)

struct SessionToolbarFilterField: View {
    @Environment(AppState.self)
    private var appState

    var body: some View {
        @Bindable
        var state = appState

        ConfigFilterField(
            searchQuery: $state.sessionSearchQuery,
            placeholder: "Find in session\u{2026}"
        )
        .frame(width: 200)
        .onChange(of: state.sessionSearchQuery) {
            state.isSessionSearchActive = !state.sessionSearchQuery.isEmpty
        }
    }
}

// MARK: - Action Buttons

struct SessionToolbarActions: View {
    let session: Session

    @State
    private var resumeTapped = false
    @State
    private var copyTapped = false
    @State
    private var revealTapped = false

    @AppStorage("openTerminalOnBash")
    private var openTerminalOnBash = false
    @AppStorage("preferredTerminal")
    private var preferredTerminal = PreferredTerminal.terminal.rawValue

    @Environment(AppState.self)
    private var appState
    @Environment(\.provider)
    private var provider

    var body: some View {
        Button {
            resumeSession()
        } label: {
            Label(
                resumeTapped ? "Copied" : "Resume",
                systemImage: resumeTapped ? "checkmark" : "arrow.uturn.forward"
            )
            .contentTransition(.symbolEffect(.replace))
        }
        .help("Copy resume command")
        .animation(.easeInOut(duration: 0.2), value: resumeTapped)

        Button {
            copyFileName()
        } label: {
            Image(systemName: copyTapped ? "checkmark" : "doc.on.doc")
                .contentTransition(.symbolEffect(.replace))
        }
        .help("Copy File Name")
        .animation(.easeInOut(duration: 0.2), value: copyTapped)

        Button {
            revealInFinder()
        } label: {
            Image(systemName: revealTapped ? "checkmark" : "folder")
                .contentTransition(.symbolEffect(.replace))
        }
        .help("Show in Finder")
        .animation(.easeInOut(duration: 0.2), value: revealTapped)
    }

    // MARK: - Actions

    private func resumeSession() {
        let command = "\(provider.cliPath) --resume \(session.id)"

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)

        if openTerminalOnBash {
            let terminal = PreferredTerminal(rawValue: preferredTerminal) ?? .terminal
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                TerminalLauncher.open(terminal)
            }
        }
        appState.showToast("Copied `\(command)`")

        resumeTapped = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            resumeTapped = false
        }
    }

    private func copyFileName() {
        guard let url = session.fileURL else { return }
        let name = url.lastPathComponent
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(name, forType: .string)

        copyTapped = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            copyTapped = false
        }
        appState.showToast("Copied `\(name)`")
    }

    private func revealInFinder() {
        guard let url = session.fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])

        revealTapped = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            revealTapped = false
        }
    }
}

// MARK: - Export

struct SessionToolbarExport: View {
    let session: Session

    @State
    private var showExportPopover = false

    var body: some View {
        Button {
            showExportPopover.toggle()
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .help("Export Session")
        .popover(isPresented: $showExportPopover, arrowEdge: .bottom) {
            ExportOptionsView(session: session)
        }
    }
}

// MARK: - Expand / Collapse

struct SessionToolbarExpandCollapse: View {
    @Environment(AppState.self)
    private var appState

    var body: some View {
        Button {
            appState.allBlocksExpanded.toggle()
        } label: {
            Image(
                systemName: appState.allBlocksExpanded
                    ? "arrow.down.right.and.arrow.up.left"
                    : "arrow.up.left.and.arrow.down.right"
            )
            .contentTransition(.symbolEffect(.replace))
        }
        .help(appState.allBlocksExpanded ? "Collapse All" : "Expand All")
    }
}

// MARK: - Tool Filter Toggle

struct SessionToolbarFilter: View {
    @Environment(AppState.self)
    private var appState

    var body: some View {
        Button {
            appState.isToolFilterActive.toggle()
            if !appState.isToolFilterActive {
                appState.activeToolFilters.removeAll()
            }
        } label: {
            Image(
                systemName: appState.isToolFilterActive
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
            .contentTransition(.symbolEffect(.replace))
        }
        .help("Filter by Tool (⌘T)")
    }
}

// MARK: - Delete

struct SessionToolbarDelete: View {
    let session: Session

    @State
    private var showDeleteConfirmation = false

    @Environment(AppState.self)
    private var appState

    var body: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            Image(systemName: "trash")
        }
        .help("Delete")
        .confirmationDialog(
            "Delete session?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                appState.deleteSession(session)
            }
        } message: {
            Text("This will permanently delete the session file. This action cannot be undone.")
        }
    }
}

// MARK: - File History

struct SessionToolbarFileHistory: View {
    let session: Session

    @Environment(AppState.self)
    private var appState

    @State
    private var fileCount = 0

    @State
    private var iconBounce = 0

    @Environment(\.fileHistoryLoader)
    private var fileHistoryLoader

    var body: some View {
        Button {
            appState.isShowingFileHistory.toggle()
            iconBounce += 1
        } label: {
            Label {
                if fileCount > 0 {
                    Text("\(fileCount)")
                }
            } icon: {
                Image(systemName: "clock.arrow.2.circlepath")
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.bounce, value: iconBounce)
            }
        }
        .help("File History (\(fileCount) files)")
        .disabled(fileCount == 0)
        .task(id: session.id) {
            let loader = fileHistoryLoader
            let count = await Task.detached {
                loader.loadFileHistory(
                    for: session.id, projectPath: session.projectPath
                ).count
            }.value
            fileCount = count
        }
    }
}

// MARK: - Debug Log

struct SessionToolbarDebugLog: View {
    let session: Session

    @Environment(AppState.self)
    private var appState

    var body: some View {
        Button {
            appState.showDebugLogSessionId = session.id
        } label: {
            Image(systemName: "ladybug")
        }
        .help("View Debug Log")
    }
}

// MARK: - Close

struct SessionToolbarClose: View {
    @Environment(AppState.self)
    private var appState

    var body: some View {
        Button {
            appState.selectedSession = nil
            appState.selectedProject = nil
        } label: {
            Image(systemName: "xmark")
        }
        .help("Close")
    }
}
