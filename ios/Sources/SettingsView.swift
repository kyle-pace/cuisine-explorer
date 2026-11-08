import SwiftUI

/// Appearance (KitchenUI's shared rows) and where everything comes from
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") { AppearanceSettings() }
                Section {
                    Text("Intros come from Wikipedia (CC BY-SA), photos from Wikimedia Commons with each one's credit, and production figures from FAOSTAT (CC BY 4.0). The recipe sites, cookbooks and notes were picked or written for this explorer.")
                        .font(Theme.callout)
                        .foregroundStyle(Theme.muted)
                    Link(destination: URL(string: "https://github.com/kyle-pace/cuisine-explorer")!) {
                        Label("The data and code on GitHub", systemImage: "arrow.up.right")
                    }
                    Link(destination: URL(string: "https://github.com/kyle-pace/cuisine-explorer/issues/new")!) {
                        Label("Suggest a correction", systemImage: "arrow.up.right")
                    }
                } header: {
                    Text("Sources")
                } footer: {
                    Text("Data refreshes weekly from \(DataSource.base.host() ?? "the server"). Pages you've opened stay available offline.")
                }
                Section {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
