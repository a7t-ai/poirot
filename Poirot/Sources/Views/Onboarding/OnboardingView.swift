import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss)
    private var dismiss
    @State
    private var currentPage = 0
    @State
    private var cliDetected = false
    @State
    private var sessionsExist = false

    private let totalPages = 3

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch currentPage {
                case 0: welcomePage
                case 1: cliCheckPage
                default: featuresPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.35), value: currentPage)

            bottomBar
        }
        .frame(width: 520, height: 480)
        .background(PoirotTheme.Colors.bgApp)
        .task {
            cliDetected = detectCLI()
            sessionsExist = checkSessionsExist()
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: PoirotTheme.Spacing.xxl) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: PoirotTheme.IconSize.xl, height: PoirotTheme.IconSize.xl)
                .clipShape(RoundedRectangle(cornerRadius: PoirotTheme.Radius.xl))

            VStack(spacing: PoirotTheme.Spacing.md) {
                Text("Welcome to Poirot")
                    .font(PoirotTheme.Typography.heroTitle)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)

                Text(
                    // swiftlint:disable:next line_length
                    "A native macOS companion for Claude Code.\nBrowse sessions, explore configurations, and search across your entire Claude Code history."
                )
                .font(PoirotTheme.Typography.body)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(PoirotTheme.Spacing.xxs)
                .frame(maxWidth: 380)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, PoirotTheme.Spacing.xxxl)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    private var cliCheckPage: some View {
        VStack(spacing: PoirotTheme.Spacing.xxl) {
            Spacer()

            Image(systemName: cliDetected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: PoirotTheme.IconSize.lg))
                .foregroundStyle(cliDetected ? PoirotTheme.Colors.green : PoirotTheme.Colors.accent)
                .contentTransition(.symbolEffect(.replace))

            VStack(spacing: PoirotTheme.Spacing.md) {
                Text(cliDetected ? "Claude Code Detected" : "Claude Code Not Found")
                    .font(PoirotTheme.Typography.heading)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)

                if cliDetected {
                    VStack(spacing: PoirotTheme.Spacing.sm) {
                        statusRow(
                            "CLI installed",
                            icon: "checkmark.circle.fill",
                            color: PoirotTheme.Colors.green
                        )
                        statusRow(
                            sessionsExist ? "Sessions found" : "No sessions yet — use Claude Code to create your first",
                            icon: sessionsExist ? "checkmark.circle.fill" : "circle.dashed",
                            color: sessionsExist ? PoirotTheme.Colors.green : PoirotTheme.Colors.textTertiary
                        )
                    }
                } else {
                    Text("Install Claude Code to get started:")
                        .font(PoirotTheme.Typography.caption)
                        .foregroundStyle(PoirotTheme.Colors.textSecondary)

                    Text("npm install -g @anthropic-ai/claude-code")
                        .font(PoirotTheme.Typography.code)
                        .foregroundStyle(PoirotTheme.Colors.textPrimary)
                        .padding(.horizontal, PoirotTheme.Spacing.lg)
                        .padding(.vertical, PoirotTheme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                                .fill(PoirotTheme.Colors.bgElevated)
                        )
                }
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, PoirotTheme.Spacing.xxxl)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    private var featuresPage: some View {
        VStack(spacing: PoirotTheme.Spacing.xxl) {
            Spacer()

            Text("Key Features")
                .font(PoirotTheme.Typography.heading)
                .foregroundStyle(PoirotTheme.Colors.textPrimary)

            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.lg) {
                featureHighlight(
                    icon: "list.bullet.rectangle.fill",
                    title: "Session Browser",
                    description: "Browse conversations grouped by project",
                    color: PoirotTheme.Colors.blue
                )
                featureHighlight(
                    icon: "magnifyingglass",
                    title: "Universal Search",
                    description: "Search everything with \u{2318}K",
                    color: PoirotTheme.Colors.accent
                )
                featureHighlight(
                    icon: "gearshape.2.fill",
                    title: "Configuration Manager",
                    description: "Manage commands, skills, MCP servers, and more",
                    color: PoirotTheme.Colors.green
                )
                featureHighlight(
                    icon: "arrow.trianglehead.2.clockwise",
                    title: "Live Reload",
                    description: "Auto-updates as you use Claude Code",
                    color: PoirotTheme.Colors.purple
                )
            }
            .frame(maxWidth: 360)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, PoirotTheme.Spacing.xxxl)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        ZStack {
            // Page indicators — centered
            HStack(spacing: PoirotTheme.Spacing.sm) {
                ForEach(0 ..< totalPages, id: \.self) { page in
                    Capsule()
                        .fill(
                            page == currentPage
                                ? PoirotTheme.Colors.accent
                                : PoirotTheme.Colors.textTertiary.opacity(0.25)
                        )
                        .frame(
                            width: page == currentPage ? PoirotTheme.Spacing.xl : PoirotTheme.Spacing.sm,
                            height: PoirotTheme.Spacing.sm
                        )
                        .animation(.easeInOut(duration: 0.25), value: currentPage)
                }
            }

            // Back + Continue — edges
            HStack {
                Button {
                    withAnimation { currentPage -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(PoirotTheme.Typography.caption)
                        .foregroundStyle(PoirotTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Go back")
                .opacity(currentPage > 0 ? 1 : 0)
                .disabled(currentPage == 0)

                Spacer()

                if currentPage < totalPages - 1 {
                    Button("Continue") {
                        withAnimation { currentPage += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Go to the next step")
                    .tint(PoirotTheme.Colors.accent)
                    .controlSize(.large)
                } else {
                    Button("Get Started") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Get started with Poirot")
                    .tint(PoirotTheme.Colors.accent)
                    .controlSize(.large)
                }
            }
        }
        .padding(.horizontal, PoirotTheme.Spacing.xxl)
        .padding(.vertical, PoirotTheme.Spacing.lg)
        .background(PoirotTheme.Colors.bgCard.opacity(0.5))
        .onKeyPress(.leftArrow) {
            guard currentPage > 0 else { return .ignored }
            withAnimation { currentPage -= 1 }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            guard currentPage < totalPages - 1 else { return .ignored }
            withAnimation { currentPage += 1 }
            return .handled
        }
    }

    // MARK: - Helpers

    private func statusRow(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: PoirotTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(color)
            Text(text)
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)
        }
    }

    private func featureHighlight(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(spacing: PoirotTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: PoirotTheme.IconSize.sm))
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)
                .frame(width: PoirotTheme.IconSize.md, height: PoirotTheme.IconSize.md)
                .background(
                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                        .fill(color.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                Text(title)
                    .font(PoirotTheme.Typography.captionMedium)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)
                Text(description)
                    .font(PoirotTheme.Typography.tiny)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            }
        }
    }

    nonisolated private func detectCLI() -> Bool {
        let paths = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "\(NSHomeDirectory())/.npm/bin/claude",
            "\(NSHomeDirectory())/.local/bin/claude",
        ]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    nonisolated private func checkSessionsExist() -> Bool {
        let projectsDir = "\(NSHomeDirectory())/.claude/projects"
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: projectsDir) else {
            return false
        }
        return !contents.isEmpty
    }
}
