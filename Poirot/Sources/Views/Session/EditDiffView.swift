import AppKit
import SwiftUI

struct EditDiffView: View {
    let oldString: String
    let newString: String
    let filePath: String?

    @State
    private var copied = false
    @State
    private var patchSaved = false
    @State
    private var imageCopied = false
    @State
    private var isContentHovered = false
    @State
    private var isButtonsHovered = false
    @State
    private var computedDiff: [DiffLine]?

    private static let maxLines = 5000

    /// Must change when either side of the diff changes — `ObjectIdentifier(Self.self)`
    /// never does, so switching files/versions previously kept the old hunks on screen.
    private var diffIdentity: String {
        "\(filePath ?? "")|\(oldString.hashValue)|\(newString.hashValue)"
    }

    private var diffLines: [DiffLine] {
        computedDiff ?? []
    }

    private var buttonOpacity: Double {
        isButtonsHovered ? 1.0 : (isContentHovered ? 0.15 : 0.5)
    }

    private var gutterWidth: CGFloat {
        let maxNum = max(
            diffLines.compactMap(\.oldLineNumber).max() ?? 0,
            diffLines.compactMap(\.newLineNumber).max() ?? 0
        )
        let digits = max(String(maxNum).count, 2)
        return CGFloat(digits) * 8 + 6
    }

    var body: some View {
        VStack(spacing: 0) {
            if computedDiff == nil {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, minHeight: 40)
            } else {
                ZStack(alignment: .topTrailing) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(diffLines) { line in
                                diffLineRow(line)
                            }
                        }
                    }
                    .padding(.vertical, PoirotTheme.Spacing.sm)

                    HStack(spacing: PoirotTheme.Spacing.xs) {
                        savePatchButton
                        copyImageButton
                        copyButton
                    }
                    .opacity(buttonOpacity)
                    .onHover { isButtonsHovered = $0 }
                    .animation(.easeInOut(duration: 0.15), value: buttonOpacity)
                    .padding(PoirotTheme.Spacing.sm)
                }
                .onHover { isContentHovered = $0 }
            }
        }
        .background(PoirotTheme.Colors.bgCode)
        .task(id: diffIdentity) {
            computedDiff = nil
            let old = oldString
            let new = newString
            let limit = Self.maxLines
            let result = await Task.detached {
                let oldLines = old.components(separatedBy: "\n")
                let newLines = new.components(separatedBy: "\n")
                if oldLines.count > limit || newLines.count > limit {
                    return LineDiff.diff(
                        oldLines: Array(oldLines.prefix(limit)),
                        newLines: Array(newLines.prefix(limit))
                    )
                }
                return LineDiff.diff(oldLines: oldLines, newLines: newLines)
            }.value
            computedDiff = result
        }
    }

    private func diffLineRow(_ line: DiffLine) -> some View {
        HStack(spacing: 0) {
            // Old line number gutter
            Text(line.oldLineNumber.map(String.init) ?? "")
                .font(PoirotTheme.Typography.codeSmall)
                .foregroundStyle(PoirotTheme.Colors.textTertiary.opacity(0.6))
                .frame(width: gutterWidth, alignment: .trailing)

            // New line number gutter
            Text(line.newLineNumber.map(String.init) ?? "")
                .font(PoirotTheme.Typography.codeSmall)
                .foregroundStyle(PoirotTheme.Colors.textTertiary.opacity(0.6))
                .frame(width: gutterWidth, alignment: .trailing)

            // +/- indicator
            Text(indicator(for: line.kind))
                .font(PoirotTheme.Typography.code)
                .foregroundStyle(indicatorColor(for: line.kind))
                .frame(width: 20, alignment: .center)

            // Code text
            Text(line.text)
                .font(PoirotTheme.Typography.code)
                .foregroundStyle(textColor(for: line.kind))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, PoirotTheme.Spacing.xs)
        .padding(.vertical, 1)
        .background(backgroundColor(for: line.kind))
    }

    private func indicator(for kind: DiffLine.Kind) -> String {
        switch kind {
        case .context: " "
        case .added: "+"
        case .removed: "-"
        }
    }

    private func indicatorColor(for kind: DiffLine.Kind) -> Color {
        switch kind {
        case .context: PoirotTheme.Colors.textTertiary
        case .added: PoirotTheme.Colors.diffAddText
        case .removed: PoirotTheme.Colors.diffRemoveText
        }
    }

    private func textColor(for kind: DiffLine.Kind) -> Color {
        switch kind {
        case .context: PoirotTheme.Colors.textSecondary
        case .added: PoirotTheme.Colors.diffAddText
        case .removed: PoirotTheme.Colors.diffRemoveText
        }
    }

    private func backgroundColor(for kind: DiffLine.Kind) -> Color {
        switch kind {
        case .context: .clear
        case .added: PoirotTheme.Colors.diffAddBg
        case .removed: PoirotTheme.Colors.diffRemoveBg
        }
    }

    // MARK: - Buttons

    private var savePatchButton: some View {
        Button {
            let path = filePath ?? "file"
            let patch = SessionExporter.toPatch(oldString: oldString, newString: newString, filePath: path)
            SessionExporter.presentPatchSavePanel(content: patch, filePath: path)
            patchSaved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                patchSaved = false
            }
        } label: {
            Image(systemName: patchSaved ? "checkmark" : "square.and.arrow.down")
                .font(PoirotTheme.Typography.tiny)
                .foregroundStyle(patchSaved ? PoirotTheme.Colors.green : PoirotTheme.Colors.textTertiary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                        .fill(PoirotTheme.Colors.bgElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                                .stroke(patchSaved ? PoirotTheme.Colors.green.opacity(0.3) : PoirotTheme.Colors.border)
                        )
                )
        }
        .buttonStyle(.plain)
        .help("Save as .patch")
        .animation(.easeInOut(duration: 0.2), value: patchSaved)
    }

    private var copyImageButton: some View {
        Button {
            copyDiffAsImage()
        } label: {
            Image(systemName: imageCopied ? "checkmark" : "photo")
                .font(PoirotTheme.Typography.tiny)
                .foregroundStyle(imageCopied ? PoirotTheme.Colors.green : PoirotTheme.Colors.textTertiary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                        .fill(PoirotTheme.Colors.bgElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                                .stroke(imageCopied ? PoirotTheme.Colors.green.opacity(0.3) : PoirotTheme.Colors.border)
                        )
                )
        }
        .buttonStyle(.plain)
        .help("Copy as image")
        .animation(.easeInOut(duration: 0.2), value: imageCopied)
    }

    @MainActor
    private func copyDiffAsImage() {
        let snapshot = DiffSnapshotView(diffLines: diffLines, gutterWidth: gutterWidth)
        let renderer = ImageRenderer(content: snapshot)
        renderer.scale = 2.0
        guard let nsImage = renderer.nsImage else { return }
        guard let tiff = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else { return }

        // Copy to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(png, forType: .png)

        // Also offer save dialog
        let filename = filePath.flatMap { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent } ?? "diff"
        SessionExporter.presentImageSavePanel(data: png, filename: filename)

        imageCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            imageCopied = false
        }
    }

    private var copyButton: some View {
        Button {
            let text = LineDiff.unifiedText(from: diffLines)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                copied = false
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(PoirotTheme.Typography.tiny)
                .foregroundStyle(copied ? PoirotTheme.Colors.green : PoirotTheme.Colors.textTertiary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                        .fill(PoirotTheme.Colors.bgElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                                .stroke(copied ? PoirotTheme.Colors.green.opacity(0.3) : PoirotTheme.Colors.border)
                        )
                )
        }
        .buttonStyle(.plain)
        .help("Copy diff text")
        .animation(.easeInOut(duration: 0.2), value: copied)
    }
}

// MARK: - Diff Snapshot View (for image export)

private struct DiffSnapshotView: View {
    let diffLines: [DiffLine]
    let gutterWidth: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach(diffLines) { line in
                HStack(spacing: 0) {
                    Text(line.oldLineNumber.map(String.init) ?? "")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.gray.opacity(0.6))
                        .frame(width: gutterWidth, alignment: .trailing)

                    Text(line.newLineNumber.map(String.init) ?? "")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.gray.opacity(0.6))
                        .frame(width: gutterWidth, alignment: .trailing)

                    Text(indicator(for: line.kind))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(indicatorColor(for: line.kind))
                        .frame(width: 20, alignment: .center)

                    Text(line.text)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(textColor(for: line.kind))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(backgroundColor(for: line.kind))
            }
        }
        .padding(.vertical, 4)
        .background(Color(nsColor: NSColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)))
    }

    private func indicator(for kind: DiffLine.Kind) -> String {
        switch kind {
        case .context: " "
        case .added: "+"
        case .removed: "-"
        }
    }

    private func indicatorColor(for kind: DiffLine.Kind) -> Color {
        switch kind {
        case .context: .gray
        case .added: .green
        case .removed: .red
        }
    }

    private func textColor(for kind: DiffLine.Kind) -> Color {
        switch kind {
        case .context: Color(white: 0.7)
        case .added: .green
        case .removed: .red
        }
    }

    private func backgroundColor(for kind: DiffLine.Kind) -> Color {
        switch kind {
        case .context: .clear
        case .added: Color.green.opacity(0.1)
        case .removed: Color.red.opacity(0.1)
        }
    }
}
