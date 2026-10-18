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
        }
        .padding(24)
        .frame(width: 280)
    }
}
