import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var store: ProcessStore

    var body: some View {
        Form {
            guardianSection
            aboutSection
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 380, minHeight: 260)
        .navigationTitle("Settings")
    }

    // MARK: - Guardian login item

    private var guardianSection: some View {
        Section {
            Toggle(
                "Start Guardian at Login",
                isOn: Binding(
                    get: { store.isGuardianLoginItem },
                    set: { enabled in
                        do {
                            try store.setGuardianLoginItem(enabled: enabled)
                        } catch {
                            store.errorMessage = "Login item error: \(error.localizedDescription)"
                        }
                    }
                )
            )

            if store.guardianLoginItemStatus == .requiresApproval {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Approval Required")
                            .fontWeight(.medium)
                        Text("Open System Settings → General → Login Items & Extensions, then allow Guardian.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Open System Settings…") {
                            store.openLoginItemSettings()
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .foregroundStyle(Color.accentColor)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Application")
        } footer: {
            Text("Individual process login behavior is controlled per-process via the \"Run at Login\" toggle in each process's settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - About section

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version") {
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Process Manager") {
                Text("macOS launchd (LaunchAgents)")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Config Storage") {
                Text("~/Library/Application Support/com.guardian.app/")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
