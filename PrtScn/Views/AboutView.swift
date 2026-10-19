import SwiftUI

struct AboutView: View {
    private let info = Bundle.main.infoDictionary ?? [:]

    var body: some View {
        VStack(spacing: 6) {
            // From the asset catalog: the system icon cache can serve a stale icon.
            Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("PrtScn").font(.title2.bold())
            Text("Version \(info["CFBundleShortVersionString"] as? String ?? "?") (\(info["CFBundleVersion"] as? String ?? "?"))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("One key, one screenshot.").padding(.top, 6)
            Link("github.com/gevgeny/PrtScn", destination: URL(string: "https://github.com/gevgeny/PrtScn")!)
                .font(.caption)
            Link("Bugs & feedback", destination: URL(string: "https://github.com/gevgeny/PrtScn/issues")!)
                .font(.caption)
            // Buy Me a Coffee brand colors: yellow #FFDD00, black text.
            Link(destination: URL(string: "https://buymeacoffee.com/eugene.g")!) {
                Text("☕ Buy me a coffee")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color(red: 1, green: 0.867, blue: 0), in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
        .padding(24)
        .frame(width: 280)
    }
}
