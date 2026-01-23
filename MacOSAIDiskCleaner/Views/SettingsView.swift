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
                        .accessibilityLabel("Save settings")
                    Button("Delete API Key") { viewModel.deleteAPIKey() }
                        .disabled(!viewModel.hasSavedAPIKey)
                        .accessibilityLabel("Delete saved API key")
                }
            }

            Section("Safety") {
                Toggle("Dry Run (do not change filesystem)", isOn: $viewModel.dryRun)
                    .accessibilityLabel("Enable dry run mode")
                Button("View Audit Log") { showAuditLog = true }
                    .accessibilityLabel("View audit log")
            }
            
            Section("Custom Rules") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Denylist (never scan/clean):")
                        .font(.caption)
                    ForEach(Array(viewModel.denylistPatterns.enumerated()), id: \.offset) { idx, pattern in
                        HStack {
                            TextField("Glob pattern", text: Binding(
                                get: { pattern },
                                set: { viewModel.denylistPatterns[idx] = $0 }
                            ))
                            Button("Remove") {
                                viewModel.denylistPatterns.remove(at: idx)
                            }
                        }
                    }
                    Button("Add Pattern") {
                        viewModel.denylistPatterns.append("")
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Allowlist (force mark as cleanable):")
                        .font(.caption)
                    ForEach(Array(viewModel.allowlistPatterns.enumerated()), id: \.offset) { idx, pattern in
                        HStack {
                            TextField("Glob pattern", text: Binding(
                                get: { pattern },
                                set: { viewModel.allowlistPatterns[idx] = $0 }
                            ))
                            Button("Remove") {
                                viewModel.allowlistPatterns.remove(at: idx)
                            }
                        }
                    }
                    Button("Add Pattern") {
                        viewModel.allowlistPatterns.append("")
                    }
                }
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

