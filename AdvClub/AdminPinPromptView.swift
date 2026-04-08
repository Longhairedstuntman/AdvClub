//
//  AdminPinPromptView.swift
//  AdvClub
//
//  Created by Chase Smith on 4/6/26.
//

import SwiftUI

struct AdminPinPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var securityManager: AdminSecurityManager

    let onSuccess: () -> Void

    @State private var pin = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Admin PIN") {
                    SecureField("Enter 4-digit PIN", text: $pin)
                        .keyboardType(.numberPad)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Unlock Admin")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Unlock") {
                        unlock()
                    }
                    .disabled(pin.count != 4)
                }
            }
        }
    }

    private func unlock() {
        let cleanedPIN = pin.filter(\.isNumber)

        guard cleanedPIN.count == 4 else {
            errorMessage = "Enter a valid 4-digit PIN."
            return
        }

        if securityManager.verify(pin: cleanedPIN) {
            dismiss()
            onSuccess()
        } else {
            errorMessage = "Incorrect PIN."
            pin = ""
        }
    }
}
