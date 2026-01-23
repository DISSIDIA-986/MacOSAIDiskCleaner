import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showAuditLog = false

    var body: some View {
        Form {
            Section("LLM") {
                TextField("Base URL", text: $viewModel.baseURLString)
                TextField("Model", text: $viewModel.model)

                SecureField("API Key (stored in Keychain)", text: $viewModel.apiKeyDraft)

                HStack {
                    Stepper("Max concurrent requests: \(viewModel.maxConcurrentRequests)", value: $viewModel.maxConcurrentRequests, in: 1...10)
                    Spacer()
                    Text(viewModel.hasSavedAPIKey ? "API Key: saved" : "API Key: not set")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Save") { viewModel.save() }
                        .keyboardShortcut(.defaultAction)
                    Button("Delete API Key") { viewModel.deleteAPIKey() }
                        .disabled(!viewModel.hasSavedAPIKey)
                }
            }

            Section("Safety") {
                Toggle("Dry Run (do not change filesystem)", isOn: $viewModel.dryRun)
                Button("View Audit Log") { showAuditLog = true }
            }

            Section("Privacy") {
                Text("Paths are sanitized before being sent to the LLM.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 540)
        .sheet(isPresented: $showAuditLog) {
            AuditLogView()
        }
    }
}

