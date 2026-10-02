#if os(macOS)
import Lygia
import SwiftUI

struct SettingsView: View {
    @AppStorage("showCompare") private var showCompare = false
    @AppStorage("lygiaRoot") private var lygiaRootOverride = ""

    var body: some View {
        Form {
            Section("Developer") {
                Toggle("Show “Compare with upstream” in the sidebar", isOn: $showCompare)
                Text("Renders a snippet with upstream LYGIA main and with the bundled fork, side by side. Also in the View menu (⇧⌘U).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("LYGIA") {
                LabeledContent("Folder") {
                    Text(lygiaRootOverride.isEmpty ? "Lygia package (\(Lygia.version ?? "bundled"))" : (lygiaRootOverride as NSString).abbreviatingWithTildeInPath)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Text("Change it from the Playground toolbar (LYGIA Folder…).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
#endif
