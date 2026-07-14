import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self)
    private var appState
    @Environment(\.provider)
    private var provider
    @AppStorage("colorTheme")
    private var colorThemeRaw = ColorTheme.default.rawValue
    var body: some View {
        VStack(spacing: 0) {
            navigationItems
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Opaque theme background — was Color.clear, which let the NavigationSplitView's system
        // sidebar material (and the desktop) show through, making light themes unreadable.
        .background(PoirotTheme.Colors.bgSidebar)
    }

    // MARK: - Navigation

    private var mainNavItems: [NavigationItem] {
        provider.navigationItems.filter { $0.section == .main }
    }

    private var configNavItems: [NavigationItem] {
        provider.navigationItems.filter { $0.section == .config }
    }

    private var allNavItems: [NavigationItem] {
        mainNavItems + configNavItems
    }

    private var navigationItems: some View {
        VStack(spacing: PoirotTheme.Spacing.xxs) {
            ForEach(Array(allNavItems.enumerated()), id: \.element.id) { index, item in
                navItemButton(for: item, index: index)
            }
        }
        .padding(PoirotTheme.Spacing.md)
        .task {
            await recomputeSidebarCounts()
        }
        .onChange(of: appState.configProjectPath) {
            Task { await recomputeSidebarCounts() }
        }
    }

    private func navItemButton(for item: NavigationItem, index: Int) -> some View {
        @Bindable
        var state = appState
        let isKeyboardSelected = appState.sidebarKeyboardIndex == index
        return Button {
            state.selectedNav = item
        } label: {
            HStack(alignment: .firstTextBaseline) {
                Label(item.title, systemImage: item.systemImage)

                Spacer()

                if let count = appState.sidebarCounts[item.id] {
                    Text("\(count)")
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(PoirotTheme.Colors.bgCard)
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(NavItemButtonStyle(
            isActive: appState.selectedNav == item,
            isKeyboardSelected: isKeyboardSelected
        ))
        .help(item.title)
    }

    private func recomputeSidebarCounts() async {
        let modelsCount = provider.supportedModels.count
        let projectPath = appState.effectiveConfigProjectPath
        let counts = await Task.detached {
            AppState.computeSidebarCounts(
                supportedModelsCount: modelsCount,
                projectPath: projectPath
            )
        }.value
        appState.sidebarCounts = counts
    }
}

// MARK: - Button Styles

private struct NavItemButtonStyle: ButtonStyle {
    let isActive: Bool
    var isKeyboardSelected: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PoirotTheme.Typography.captionMedium)
            .foregroundStyle(isActive ? PoirotTheme.Colors.accent : PoirotTheme.Colors.textSecondary)
            .padding(.vertical, 6)
            .padding(.horizontal, PoirotTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                    .fill(isActive ? PoirotTheme.Colors.accentDim : .clear)
            )
            .contentShape(Rectangle())
            .overlay(
                RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                    .strokeBorder(
                        PoirotTheme.Colors.accent.opacity(isKeyboardSelected ? 0.5 : 0),
                        lineWidth: 1
                    )
            )
    }
}
