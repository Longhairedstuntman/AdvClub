//
//  UserManagementView.swift
//  AdvClub
//
//  Created by Chase Smith on 4/9/26.
//

import SwiftUI

struct UserManagementView: View {
    @EnvironmentObject private var sessionManager: SessionManager

    @State private var userDisplayName = ""
    @State private var userEmail = ""
    @State private var userPassword = ""
    @State private var selectedRole: UserRole = .member
    @State private var userMessage: String?

    private var sortedUsers: [AppUser] {
        sessionManager.allUsers()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                createUserSection
                usersListSection
            }
            .padding(24)
            .foregroundStyle(.white)
        }
        .background(Color.appBackgroundColor)
        .navigationTitle("User Management")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var createUserSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create User")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Firebase Authentication is now the source of truth for user accounts. Secure admin-created user provisioning should be handled with a Cloud Function or another trusted backend, not directly from the client app.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))

            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                TextField("Enter full name", text: $userDisplayName)
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                TextField("Enter email", text: $userEmail)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Temporary Password")
                SecureField("Enter temporary password", text: $userPassword)
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Role")
                Picker("Role", selection: $selectedRole) {
                    Text("Member").tag(UserRole.member)
                    Text("Admin").tag(UserRole.admin)
                }
                .pickerStyle(.segmented)
            }

            Button {
                Task {
                    let result = await sessionManager.createMember(
                        email: userEmail,
                        password: userPassword,
                        displayName: userDisplayName,
                        role: selectedRole
                    )

                    await MainActor.run {
                        switch result {
                        case .success(let user):
                            userMessage = "Created \(user.role.rawValue): \(user.displayName)"
                            resetCreateUserForm()
                        case .failure(let error):
                            userMessage = error.localizedDescription
                        }
                    }
                }
            } label: {
                Text("Create User")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if let userMessage {
                Text(userMessage)
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

    private var usersListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Users")
                .font(.title2)
                .fontWeight(.semibold)

            if sortedUsers.isEmpty {
                Text("No users found.")
                    .foregroundStyle(.white.opacity(0.68))
            } else {
                ForEach(sortedUsers) { user in
                    NavigationLink {
                        EditUserView(user: user)
                    } label: {
                        userRow(for: user)
                    }
                    .buttonStyle(.plain)

                    if user.id != sortedUsers.last?.id {
                        Divider()
                            .overlay(Color.white.opacity(0.08))
                    }
                }
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

    private func userRow(for user: AppUser) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.headline)

                Text(user.email)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))

                Text(user.role.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text(user.isActive ? "Active" : "Inactive")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(user.isActive ? Color.white : Color.white.opacity(0.12))
                    .foregroundStyle(user.isActive ? .black : .white)
                    .clipShape(Capsule())

                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(.vertical, 8)
    }

    private func resetCreateUserForm() {
        userDisplayName = ""
        userEmail = ""
        userPassword = ""
        selectedRole = .member
    }
}

#Preview {
    NavigationStack {
        UserManagementView()
            .environmentObject(SessionManager())
    }
}
