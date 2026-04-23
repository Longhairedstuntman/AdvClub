//
//  EditUserView.swift
//  AdvClub
//
//  Created by Chase Smith on 4/9/26.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct EditUserView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss

    let user: AppUser

    @State private var displayName: String
    @State private var email: String
    @State private var newPassword: String = ""
    @State private var role: UserRole
    @State private var isActive: Bool
    @State private var quarterlyAllowance: Int
    @State private var message: String?

    init(user: AppUser) {
        self.user = user
        _displayName = State(initialValue: user.displayName)
        _email = State(initialValue: user.email)
        _role = State(initialValue: user.role)
        _isActive = State(initialValue: user.isActive)
        _quarterlyAllowance = State(initialValue: user.quarterlyAllowance)
    }

    private var isCurrentUser: Bool {
        sessionManager.currentUser?.id == user.id
    }

    private var canManageTargetUser: Bool {
        if sessionManager.isSuperAdmin {
            return user.role != .superAdmin || isCurrentUser
        }

        if sessionManager.isAdmin {
            return user.role == .member || isCurrentUser
        }

        return isCurrentUser
    }

    private var canDeleteTargetUser: Bool {
        if sessionManager.isSuperAdmin {
            return user.role != .superAdmin
        }

        if sessionManager.isAdmin {
            return user.role == .member
        }

        return false
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
            quarterlyAllowanceSection

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
            } else if canManageTargetUser {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Send a password reset email to this user.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white.opacity(0.8))

                    Button {
                        Auth.auth().sendPasswordReset(withEmail: email) { error in
                            if let error {
                                message = error.localizedDescription
                            } else {
                                message = "Password reset email sent to \(email)."
                            }
                        }
                    } label: {
                        Text("Send Password Reset Email")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.12))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            } else {
                Text("You do not have permission to reset this user’s password.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    @ViewBuilder
    private var roleFieldSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Role")

            if user.role == .superAdmin {
                Text("Super Admin")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white.opacity(0.8))

                Text("Super Admin accounts are protected and cannot be reassigned from this screen.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            } else if sessionManager.isSuperAdmin {
                Picker("Role", selection: $role) {
                    Text("Member").tag(UserRole.member)
                    Text("Admin").tag(UserRole.admin)
                }
                .pickerStyle(.segmented)
            } else {
                Text(role == .admin ? "Admin" : "Member")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white.opacity(0.8))

                Text("Only a Super Admin can change another user’s role.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
    }

    private var activeToggleSection: some View {
        Toggle("Active", isOn: $isActive)
            .disabled(canManageTargetUser == false || user.role == .superAdmin)
            .opacity((canManageTargetUser == false || user.role == .superAdmin) ? 0.6 : 1)
    }

    @ViewBuilder
    private var quarterlyAllowanceSection: some View {
        if user.role == .member {
            VStack(alignment: .leading, spacing: 12) {
                Text("Available Days")

                HStack(spacing: 12) {
                    Button {
                        quarterlyAllowance = max(0, quarterlyAllowance - 1)
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(canManageTargetUser == false)

                    Text("\(quarterlyAllowance) days")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Button {
                        quarterlyAllowance += 1
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(canManageTargetUser == false)
                }

                Text("Adjust the member's available days directly from the admin editor.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }
            .opacity(canManageTargetUser ? 1 : 0.6)
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                Task {
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
                        do {
                            try await Firestore.firestore().collection("users").document(user.id).updateData([
                                "quarterlyAllowance": quarterlyAllowance,
                                "updatedAt": FieldValue.serverTimestamp(),
                            ])
                            dismiss()
                        } catch {
                            message = error.localizedDescription
                        }
                    case .failure(let error):
                        message = error.localizedDescription
                    }
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
            .disabled(canManageTargetUser == false && isCurrentUser == false)
            .opacity((canManageTargetUser || isCurrentUser) ? 1 : 0.6)

            if canDeleteTargetUser {
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
