import SwiftUI

struct FileHistoryView: View {
    let session: Session

    @State
    private var entries: [FileHistoryEntry] = []

    @State
    private var selectedFile: FileHistoryEntry?

    @State
    private var selectedVersionIndex: Int?

    @State
    private var fileContents: [String: String] = [:]

    @State
    private var isLoading = true

    @State
    private var iconBounce = 0

    @Environment(\.fileHistoryLoader)
    private var fileHistoryLoader

    @Environment(AppState.self)
    private var appState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            if isLoading {
                loadingState
            } else if entries.isEmpty {
                emptyState
            } else {
                HSplitView {
                    fileList
                        .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
                    versionDetail
                        .frame(minWidth: 400, idealWidth: 600)
                }
            }
        }
        .background(PoirotTheme.Colors.bgApp)
        .task {
            await loadHistory()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: PoirotTheme.Spacing.md) {
            Image(systemName: "clock.arrow.2.circlepath")
                .font(PoirotTheme.Typography.headingSmall)
                .foregroundStyle(PoirotTheme.Colors.accent)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.bounce, value: iconBounce)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                        .fill(PoirotTheme.Colors.accent.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                Text("File History")
                    .font(PoirotTheme.Typography.heading)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)

                Text("\(entries.count) \(entries.count == 1 ? "file" : "files") changed")
                    .font(PoirotTheme.Typography.caption)
                    .foregroundStyle(PoirotTheme.Colors.textSecondary)
            }

            Spacer()

            Button {
                appState.isShowingFileHistory = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(PoirotTheme.Typography.large)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, PoirotTheme.Spacing.xl)
        .padding(.vertical, PoirotTheme.Spacing.lg)
    }

    // MARK: - File List

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: PoirotTheme.Spacing.xxs) {
                ForEach(entries) { entry in
                    fileRow(entry)
                }
            }
            .padding(PoirotTheme.Spacing.sm)
        }
        .background(PoirotTheme.Colors.bgSidebar)
    }

    private func fileRow(_ entry: FileHistoryEntry) -> some View {
        let isSelected = selectedFile?.id == entry.id
        return Button {
            selectedFile = entry
            selectedVersionIndex = nil
        } label: {
            HStack(spacing: PoirotTheme.Spacing.sm) {
                Image(systemName: iconForFile(entry.fileName))
                    .font(PoirotTheme.Typography.caption)
                    .foregroundStyle(isSelected ? PoirotTheme.Colors.accent : PoirotTheme.Colors.textSecondary)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.fileName.components(separatedBy: "/").last ?? entry.fileName)
                        .font(PoirotTheme.Typography.captionMedium)
                        .foregroundStyle(isSelected ? PoirotTheme.Colors.textPrimary : PoirotTheme.Colors.textSecondary)
                        .lineLimit(1)

                    if entry.fileName.contains("/") {
                        Text(directoryPath(entry.fileName))
                            .font(PoirotTheme.Typography.micro)
                            .foregroundStyle(PoirotTheme.Colors.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text("\(entry.editCount)")
                    .font(PoirotTheme.Typography.microSemibold)
                    .foregroundStyle(isSelected ? PoirotTheme.Colors.accent : PoirotTheme.Colors.textTertiary)
                    .padding(.horizontal, PoirotTheme.Spacing.sm)
                    .padding(.vertical, PoirotTheme.Spacing.xxs)
                    .background(
                        Capsule()
                            .fill(
                                isSelected
                                    ? PoirotTheme.Colors.accent.opacity(0.15)
                                    : PoirotTheme.Colors.bgElevated
                            )
                    )
            }
            .padding(.horizontal, PoirotTheme.Spacing.md)
            .padding(.vertical, PoirotTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                    .fill(isSelected ? PoirotTheme.Colors.accentDim : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(entry.fileName)
    }

    // MARK: - Version Detail

    private var versionDetail: some View {
        Group {
            if let file = selectedFile {
                VStack(spacing: 0) {
                    versionTimeline(for: file)
                    Divider().opacity(0.3)
                    diffContent(for: file)
                }
            } else {
                placeholderState
            }
        }
        .background(PoirotTheme.Colors.bgApp)
    }

    private func versionTimeline(for entry: FileHistoryEntry) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PoirotTheme.Spacing.sm) {
                ForEach(Array(entry.versions.enumerated()), id: \.element.id) { index, version in
                    let isSelected = selectedVersionIndex == index
                        || (selectedVersionIndex == nil && index == entry.versions.count - 1)
                    Button {
                        selectedVersionIndex = index
                        Task { await loadVersionContent(entry: entry, versionIndex: index) }
                    } label: {
                        HStack(spacing: PoirotTheme.Spacing.xs) {
                            Image(systemName: isSelected ? "circle.fill" : "circle")
                                .font(.system(size: 6))
                                .foregroundStyle(
                                    isSelected ? PoirotTheme.Colors.accent : PoirotTheme.Colors.textTertiary
                                )

                            Text("v\(version.version)")
                                .font(PoirotTheme.Typography.microSemibold)
                                .foregroundStyle(
                                    isSelected ? PoirotTheme.Colors.accent : PoirotTheme.Colors.textSecondary
                                )

                            Text(formattedTime(version.backupTime))
                                .font(PoirotTheme.Typography.micro)
                                .foregroundStyle(PoirotTheme.Colors.textTertiary)
                        }
                        .padding(.horizontal, PoirotTheme.Spacing.md)
                        .padding(.vertical, PoirotTheme.Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                                .fill(isSelected ? PoirotTheme.Colors.accentDim : PoirotTheme.Colors.bgCard)
                                .overlay(
                                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                                        .stroke(
                                            isSelected
                                                ? PoirotTheme.Colors.accent.opacity(0.3)
                                                : PoirotTheme.Colors.border
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .help("View version \(version.version)")
                }
            }
            .padding(.horizontal, PoirotTheme.Spacing.lg)
        }
        .padding(.vertical, PoirotTheme.Spacing.md)
        .background(PoirotTheme.Colors.bgCard)
    }

    private func diffContent(for entry: FileHistoryEntry) -> some View {
        let effectiveIndex = selectedVersionIndex ?? entry.versions.count - 1
        let version = entry.versions[effectiveIndex]
        let currentKey = "\(session.id)/\(version.backupFileName)"

        return Group {
            if effectiveIndex > 0 {
                let previousVersion = entry.versions[effectiveIndex - 1]
                let previousKey = "\(session.id)/\(previousVersion.backupFileName)"
                let oldContent = fileContents[previousKey] ?? ""
                let newContent = fileContents[currentKey] ?? ""

                if oldContent.isEmpty, newContent.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .task(id: currentKey) {
                            await loadVersionContent(entry: entry, versionIndex: effectiveIndex)
                        }
                } else {
                    ScrollView {
                        EditDiffView(
                            oldString: oldContent,
                            newString: newContent,
                            filePath: entry.fileName
                        )
                    }
                }
            } else {
                // First version — show full content as "added"
                let content = fileContents[currentKey] ?? ""
                if content.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .task(id: currentKey) {
                            await loadVersionContent(entry: entry, versionIndex: effectiveIndex)
                        }
                } else {
                    ScrollView {
                        EditDiffView(
                            oldString: "",
                            newString: content,
                            filePath: entry.fileName
                        )
                    }
                }
            }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: PoirotTheme.Spacing.md) {
            ProgressView()
            Text("Loading file history\u{2026}")
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: PoirotTheme.Spacing.lg) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: PoirotTheme.IconSize.lg))
                .foregroundStyle(PoirotTheme.Colors.textTertiary.opacity(0.5))
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: PoirotTheme.Spacing.xs) {
                Text("No File History")
                    .font(PoirotTheme.Typography.headingSmall)
                    .foregroundStyle(PoirotTheme.Colors.textSecondary)

                Text("No versioned file snapshots were found for this session.")
                    .font(PoirotTheme.Typography.caption)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placeholderState: some View {
        VStack(spacing: PoirotTheme.Spacing.md) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: PoirotTheme.IconSize.md))
                .foregroundStyle(PoirotTheme.Colors.textTertiary.opacity(0.4))
                .symbolRenderingMode(.hierarchical)

            Text("Select a file to view changes")
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data Loading

    private func loadHistory() async {
        let loader = fileHistoryLoader
        let sessionId = session.id
        let projectPath = session.projectPath
        let loaded = await Task.detached {
            loader.loadFileHistory(for: sessionId, projectPath: projectPath)
        }.value
        entries = loaded
        isLoading = false
        iconBounce += 1

        // Auto-select first file
        if let first = entries.first {
            selectedFile = first
            await loadVersionContent(entry: first, versionIndex: first.versions.count - 1)
        }
    }

    private func loadVersionContent(entry: FileHistoryEntry, versionIndex: Int) async {
        let loader = fileHistoryLoader
        let sessionId = session.id

        // Load the selected version
        let version = entry.versions[versionIndex]
        let key = "\(sessionId)/\(version.backupFileName)"
        if fileContents[key] == nil {
            let content = await Task.detached {
                loader.loadFileContent(for: sessionId, backupFileName: version.backupFileName)
            }.value
            fileContents[key] = content ?? ""
        }

        // Also load previous version for diff
        if versionIndex > 0 {
            let prev = entry.versions[versionIndex - 1]
            let prevKey = "\(sessionId)/\(prev.backupFileName)"
            if fileContents[prevKey] == nil {
                let content = await Task.detached {
                    loader.loadFileContent(for: sessionId, backupFileName: prev.backupFileName)
                }.value
                fileContents[prevKey] = content ?? ""
            }
        }
    }

    // MARK: - Helpers

    private func iconForFile(_ fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "ts", "jsx", "tsx": return "curlybraces"
        case "json": return "curlybraces.square"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "md", "txt": return "doc.text"
        case "yml", "yaml", "toml": return "list.bullet.rectangle"
        case "html", "css": return "globe"
        case "sh", "zsh", "bash": return "terminal"
        case "rs", "go", "rb", "java", "kt", "c", "cpp", "h", "m": return "chevron.left.forwardslash.chevron.right"
        default: return "doc"
        }
    }

    private func directoryPath(_ fileName: String) -> String {
        let components = fileName.components(separatedBy: "/")
        return components.dropLast().joined(separator: "/")
    }

    private static let timeFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt
    }()

    private func formattedTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }
}
