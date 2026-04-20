//
//  EditUserView.swift
//  AdvClub
//
//  Created by Chase Smith on 4/9/26.
//

import SwiftUI

struct EditUserView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss

    let user: AppUser

    @State private var displayName: String
    @State private var email: String
    @State private var newPassword: String = ""
    @State private var role: UserRole
    @State private var isActive: Bool
    @State private var message: String?

    init(user: AppUser) {
        self.user = user
        _displayName = State(initialValue: user.displayName)
        _email = State(initialValue: user.email)
        _role = State(initialValue: user.role)
        _isActive = State(initialValue: user.isActive)
    }

    private var isCurrentUser: Bool {
        sessionManager.currentUser?.id == user.id
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                editFormSection
                actionsSection
            }
            .padding(24)
            .foregroundStyle(.white)
        }
        .background(Color.appBackgroundColor)
        .navigationTitle("Edit User")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var editFormSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            nameFieldSection
            emailFieldSection
            passwordFieldSection
            roleFieldSection
            activeToggleSection

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var nameFieldSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
            TextField("Enter full name", text: $displayName)
                .padding()
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var emailFieldSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Email")
            Text(email)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white.opacity(0.8))

            Text("Email changes are not enabled from the client app in the Firebase flow.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
        }
    }

    @ViewBuilder
    private var passwordFieldSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Password")

            if isCurrentUser {
                SecureField("Enter a new password", text: $newPassword)
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text("Leave blank to keep the current password.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            } else {
                Text("Password changes for other users should be handled through a secure backend or Cloud Function.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    private var roleFieldSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Role")
            Picker("Role", selection: $role) {
                Text("Member").tag(UserRole.member)
                Text("Admin").tag(UserRole.admin)
            }
            .pickerStyle(.segmented)
        }
    }

    private var activeToggleSection: some View {
        Toggle("Active", isOn: $isActive)
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                let result = sessionManager.updateUser(
                    userID: user.id,
                    email: email,
                    password: isCurrentUser ? newPassword : "",
                    displayName: displayName,
                    role: role,
                    isActive: isActive
                )

                switch result {
                case .success:
                    dismiss()
                case .failure(let error):
                    message = error.localizedDescription
                }
            } label: {
                Text("Save Changes")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if user.role != .admin {
                Button(role: .destructive) {
                    sessionManager.deleteUser(userID: user.id)
                    dismiss()
                } label: {
                    Text("Delete User")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.18))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        EditUserView(
            user: AppUser(
                id: "preview-user-id",
                email: "member@advclub.local",
                displayName: "Test Member",
                role: .member,
                isActive: true,
                quarterlyAllowance: 30
            )
        )
        .environmentObject(SessionManager())
    }
}
