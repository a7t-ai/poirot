import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String?
    let icon: String
    let color: Color
    var dimmed: Bool = false
    var info: String?

    var body: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)

                Spacer()

                if let info {
                    InfoTooltipButton(text: info)
                }
            }

            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                Text(value)
                    .font(PoirotTheme.Typography.heading)
                    .foregroundStyle(dimmed ? PoirotTheme.Colors.textTertiary : PoirotTheme.Colors.textPrimary)

                Text(title)
                    .font(PoirotTheme.Typography.small)
                    .foregroundStyle(PoirotTheme.Colors.textSecondary)

                Group {
                    if let subtitle {
                        Text(subtitle)
                    } else {
                        Text(" ")
                    }
                }
                .font(PoirotTheme.Typography.micro)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
            }
        }
        .padding(PoirotTheme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                .fill(PoirotTheme.Colors.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                .stroke(PoirotTheme.Colors.border, lineWidth: 1)
        )
    }
}
