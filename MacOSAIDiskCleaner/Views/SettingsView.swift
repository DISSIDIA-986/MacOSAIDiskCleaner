import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showAuditLog = false

    var body: some View {
        Form {
            Section("LLM Provider") {
                Picker("Provider", selection: $viewModel.selectedProvider) {
                    ForEach(SettingsViewModel.LLMProvider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .onChange(of: viewModel.selectedProvider) { newValue in
                    viewModel.applyProvider(newValue)
                }

                TextField("Base URL", text: $viewModel.baseURLString)
                    .disabled(viewModel.selectedProvider != .custom)
                TextField("Model", text: $viewModel.model)
                    .disabled(viewModel.selectedProvider != .custom)

                SecureField("API Key (stored in Keychain)", text: $viewModel.apiKeyDraft)

                HStack {
                    Stepper("Max concurrent: \(viewModel.maxConcurrentRequests)", value: $viewModel.maxConcurrentRequests, in: 1...10)
                    Spacer()
                    Text(viewModel.hasSavedAPIKey ? "API Key: saved" : "API Key: not set")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Save") { viewModel.save() }
                        .keyboardShortcut(.defaultAction)
                        .accessibilityLabel("Save settings")

                    Button {
                        viewModel.testConnection()
                    } label: {
                        if viewModel.isTestingConnection {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Testing...")
                            }
                        } else {
                            Label("Test", systemImage: "bolt.circle")
                        }
                    }
                    .disabled(viewModel.isTestingConnection || !viewModel.hasSavedAPIKey)
                    .accessibilityLabel("Test API connection")

                    Button("Delete API Key") { viewModel.deleteAPIKey() }
                        .disabled(!viewModel.hasSavedAPIKey)
                        .accessibilityLabel("Delete saved API key")
                }

                if let status = viewModel.connectionStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(status.contains("✅") ? .green : .red)
                }
            }

            Section("Developer Profile") {
                Text("Select your development stacks for smarter AI analysis:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Swift / Xcode", isOn: $viewModel.devSwift)
                Toggle("Python", isOn: $viewModel.devPython)
                Toggle("Node.js", isOn: $viewModel.devNodeJS)
                Toggle("Ruby", isOn: $viewModel.devRuby)
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

