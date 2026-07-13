import SwiftUI

struct AboutView: View {
    @Environment(\.openURL)
    private var openURL

    var body: some View {
        HStack(spacing: 24) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)

            VStack(alignment: .leading, spacing: 6) {
                Text("Poirot")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Version \(Bundle.main.appVersion) (\(Bundle.main.buildNumber))")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Spacer()
                    .frame(height: 4)

                Text("Your Claude Code companion")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("Open source project") {
                        if let url = URL(string: "https://github.com/a7t-ai/poirot") {
                            openURL(url)
                        }
                    }
                    .buttonStyle(.link)
                    .help("Open the project on GitHub")
                    .font(.system(size: 12))

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Button {
                        if let url = URL(string: "https://github.com/sponsors/leonardocardoso") {
                            openURL(url)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.pink)
                            Text("Sponsor")
                        }
                    }
                    .buttonStyle(.link)
                    .help("Sponsor on GitHub")
                    .font(.system(size: 12))
                }

                Spacer()
                    .frame(height: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Leonardo Cardoso")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Button("@leocardz") {
                        if let url = URL(string: "https://threads.net/@leocardz") {
                            openURL(url)
                        }
                    }
                    .buttonStyle(.link)
                    .help("Open Threads profile")
                    .font(.system(size: 10))

                    Button("leo@leocardz.com") {
                        if let url = URL(string: "mailto:leo@leocardz.com") {
                            openURL(url)
                        }
                    }
                    .buttonStyle(.link)
                    .help("Send an email")
                    .font(.system(size: 10))
                }
            }
        }
        .padding(24)
        .frame(width: 420)
        .fixedSize()
    }
}
