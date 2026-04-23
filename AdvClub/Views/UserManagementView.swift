//
//  UserManagementView.swift
//  AdvClub
//
//  Created by Chase Smith on 4/9/26
//

import SwiftUI

struct UserManagementView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    managementOptionsSection
                }
                .padding(24)
                .foregroundStyle(.white)
            }
            .background(Color.appBackgroundColor)
            .navigationTitle("User Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.black)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("User Management")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Organize how member and admin accounts are created, reviewed, and managed.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private var managementOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            NavigationLink {
                CreateUserAdminPage()
            } label: {
                managementCard(
                    title: "Create User",
                    subtitle: "Create a new member or admin account using the user provisioning flow.",
                    systemImage: "person.badge.plus"
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                CurrentUsersAdminPage()
            } label: {
                managementCard(
                    title: "Current Users",
                    subtitle: "Review and manage the member and admin accounts already in the system.",
                    systemImage: "person.2.fill"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func managementCard(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.6))
                .padding(.top, 6)
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct CreateUserAdminPage: View {
    @EnvironmentObject private var sessionManager: SessionManager

    @State private var userDisplayName = ""
    @State private var userEmail = ""
    @State private var userPassword = ""
    @State private var selectedRole: UserRole = .member
    @State private var userMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Create User")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("Create a new member or admin account. Firebase Authentication remains the source of truth for user credentials.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }

                VStack(alignment: .leading, spacing: 16) {
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

                        if sessionManager.isSuperAdmin {
                            Picker("Role", selection: $selectedRole) {
                                Text("Member").tag(UserRole.member)
                                Text("Admin").tag(UserRole.admin)
                            }
                            .pickerStyle(.segmented)
                        } else {
                            Text("Member")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .foregroundStyle(.white.opacity(0.8))

                            Text("Only a Super Admin can create another admin account.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.58))
                        }
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
            .padding(24)
            .foregroundStyle(.white)
        }
        .background(Color.appBackgroundColor)
        .navigationTitle("Create User")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func resetCreateUserForm() {
        userDisplayName = ""
        userEmail = ""
        userPassword = ""
        selectedRole = .member
    }
}

private struct CurrentUsersAdminPage: View {
    @EnvironmentObject private var sessionManager: SessionManager

    private var superAdminUsers: [AppUser] {
        sessionManager.allUsers().filter { $0.role == .superAdmin }
    }

    private var adminUsers: [AppUser] {
        sessionManager.allUsers().filter { $0.role == .admin }
    }

    private var memberUsers: [AppUser] {
        sessionManager.allUsers().filter { $0.role == .member }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Current Users")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("Review and manage the users currently available in the system.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }

                VStack(alignment: .leading, spacing: 20) {
                    if superAdminUsers.isEmpty == false {
                        userSection(title: "Super Admins", users: superAdminUsers)
                    }

                    if adminUsers.isEmpty == false {
                        userSection(title: "Admins", users: adminUsers)
                    }

                    if memberUsers.isEmpty == false {
                        userSection(title: "Members", users: memberUsers)
                    }

                    if superAdminUsers.isEmpty && adminUsers.isEmpty && memberUsers.isEmpty {
                        Text("No users found.")
                            .foregroundStyle(.white.opacity(0.68))
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
            .padding(24)
            .foregroundStyle(.white)
        }
        .background(Color.appBackgroundColor)
        .navigationTitle("Current Users")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func userSection(title: String, users: [AppUser]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            ForEach(users) { user in
                NavigationLink {
                    EditUserView(user: user)
                } label: {
                    userRow(for: user)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if user.id != users.last?.id {
                    Divider()
                        .overlay(Color.white.opacity(0.08))
                }
            }
        }
    }

    private func displayRoleLabel(for role: UserRole) -> String {
        switch role {
        case .superAdmin:
            return "Super Admin"
        case .admin:
            return "Admin"
        case .member:
            return "Member"
        }
    }

    private func userRow(for user: AppUser) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.headline)

                Text(user.email)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))

                Text(displayRoleLabel(for: user.role))
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
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        UserManagementView()
            .environmentObject(SessionManager())
    }
}
