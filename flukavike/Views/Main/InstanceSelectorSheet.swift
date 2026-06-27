//
//  InstanceSelectorSheet.swift
//  Self-hosted instance discovery and selection
//

import SwiftUI

struct InstanceSelectorSheet: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @Binding var instance: String

    @State private var customInstance: String = ""
    @State private var isDiscovering: Bool = false
    @State private var discoveredInstances: [DiscoveredInstance] = []
    @State private var errorMessage: String?

    private let popularInstances = [
        "fluxer.app",
        "web.fluxer.app"
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Official") {
                    ForEach(popularInstances, id: \.self) { inst in
                        Button {
                            instance = inst
                            dismiss()
                        } label: {
                            Text(inst)
                                .foregroundStyle(themeManager.textPrimary(colorScheme))
                        }
                    }
                }

                Section("Custom instance") {
                    TextField("instance.example.com", text: $customInstance)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                    }

                    Button("Connect") {
                        discover(instance: customInstance)
                    }
                    .disabled(customInstance.isEmpty || isDiscovering)
                }

                if !discoveredInstances.isEmpty {
                    Section("Discovered") {
                        ForEach(discoveredInstances) { inst in
                            Button {
                                instance = inst.displayDomain
                                dismiss()
                            } label: {
                                Text(inst.displayDomain)
                                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Instance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                }
            }
        }
    }

    private func discover(instance: String) {
        isDiscovering = true
        errorMessage = nil

        Task {
            do {
                try await APIService.shared.discoverInstance(instance)
                await MainActor.run {
                    isDiscovering = false
                    self.instance = APIService.shared.currentInstance
                    discoveredInstances = [DiscoveredInstance(displayDomain: APIService.shared.currentInstance)]
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDiscovering = false
                    errorMessage = "Could not connect to \(instance)."
                }
            }
        }
    }
}

private struct DiscoveredInstance: Identifiable {
    let id = UUID()
    let displayDomain: String
}
