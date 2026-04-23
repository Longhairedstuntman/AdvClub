//
//  AdminView.swift
//  AdvClub
//
//  Created by Chase Smith on 4/9/26.
//

import Foundation
import SwiftUI
import Combine

struct AdminView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @State private var isPresentingResourceManagementSheet = false
    @State private var isPresentingUserManagementSheet = false
    @State private var isPresentingContentManagementSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Admin")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("Manage users, content, and app administration tools.")
                    .foregroundStyle(.white.opacity(0.72))

                Button {
                    isPresentingUserManagementSheet = true
                } label: {
                    adminCard(
                        title: "User Management",
                        subtitle: "Create users, assign roles, and edit member or admin accounts.",
                        systemImage: "person.2.fill"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    isPresentingContentManagementSheet = true
                } label: {
                    adminCard(
                        title: "Content Management",
                        subtitle: "Manage events, updates, and app content.",
                        systemImage: "square.and.pencil"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    isPresentingResourceManagementSheet = true
                } label: {
                    adminCard(
                        title: "Resource Management",
                        subtitle: "Manage the reservable items members can request, such as cars, boats, garage access, and simulators.",
                        systemImage: "shippingbox.fill"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    sessionManager.logout()
                } label: {
                    Text("Log Out")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(24)
            .foregroundStyle(.white)
        }
        .background(Color.appBackgroundColor)
        .sheet(isPresented: $isPresentingUserManagementSheet) {
                UserManagementView()
        }
        .sheet(isPresented: $isPresentingContentManagementSheet) {
                ContentManagementView()
        }
        .sheet(isPresented: $isPresentingResourceManagementSheet) {
            ResourceManagementView()
        }
    }

    private func adminCard(title: String, subtitle: String, systemImage: String) -> some View {
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

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 4)
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

#Preview {
    NavigationStack {
        AdminView()
            .environmentObject(SessionManager())
            .environmentObject(ResourceManager())
    }
}
