//
//  ResourceManagementView.swift
//  AdvClub
//
//  Created by Chase Smith on 4/14/26.
//

import SwiftUI

struct ResourceManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var resourceManager: ResourceManager

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
            .navigationTitle("Resources")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                _ = await resourceManager.seedDefaultResourcesIfNeeded()
            }
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
            Text("Resource Management")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Organize how reservable resources are created and managed for members and admins.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private var managementOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            NavigationLink {
                AddResourceAdminPage()
            } label: {
                managementCard(
                    title: "Add Resource",
                    subtitle: "Create a new reservable resource and prepare it for member reservations.",
                    systemImage: "plus.circle.fill"
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                CurrentResourcesAdminPage()
            } label: {
                managementCard(
                    title: "Current Resources",
                    subtitle: "View, edit, enable, disable, and remove the resources currently available.",
                    systemImage: "shippingbox.fill"
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

private struct AddResourceAdminPage: View {
    @EnvironmentObject private var resourceManager: ResourceManager

    @State private var newResourceName = ""
    @State private var reservationMode: ResourceReservationMode = .daily
    @State private var countsTowardQuarterlyDays = false
    @State private var maxConsecutiveHoursText = ""
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Add Resource")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("Create a new reservable resource and define whether it is daily or hourly and whether member use consumes a quarterly day.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Resource Name")
                        .font(.title3)
                        .fontWeight(.semibold)

                    TextField("Enter resource name", text: $newResourceName)
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reservation Mode")
                            .font(.subheadline.weight(.semibold))

                        Picker("Reservation Mode", selection: $reservationMode) {
                            ForEach(ResourceReservationMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(.black)
                        .colorScheme(.dark)
                    }

                    Toggle("Counts toward quarterly days", isOn: $countsTowardQuarterlyDays)
                        .tint(.white)

                    if reservationMode == .hourly {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Max Consecutive Hours")
                                .font(.subheadline.weight(.semibold))

                            TextField("Optional max hours", text: $maxConsecutiveHoursText)
                                .keyboardType(.numberPad)
                                .padding()
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    Button {
                        Task {
                            await addResource()
                        }
                    } label: {
                        Text("Add Resource")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.72))
                    } else if let errorMessage = resourceManager.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.72))
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
        .navigationTitle("Add Resource")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addResource() async {
        let maxHours = Int(maxConsecutiveHoursText.trimmingCharacters(in: .whitespacesAndNewlines))
        let result = await resourceManager.addResource(
            name: newResourceName,
            reservationMode: reservationMode,
            countsTowardQuarterlyDays: countsTowardQuarterlyDays,
            maxConsecutiveHours: reservationMode == .hourly ? maxHours : nil,
            isEnabled: true
        )

        switch result {
        case .success(let resource):
            newResourceName = ""
            reservationMode = .daily
            countsTowardQuarterlyDays = false
            maxConsecutiveHoursText = ""
            message = "Added \(resource.name)."
        case .failure(let error):
            message = error.localizedDescription
        }
    }
}

private struct CurrentResourcesAdminPage: View {
    @EnvironmentObject private var resourceManager: ResourceManager
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Current Resources")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("Manage the resources currently available to members.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Existing Resources")
                        .font(.title3)
                        .fontWeight(.semibold)

                    if resourceManager.resources.isEmpty {
                        Text("No resources added yet.")
                            .foregroundStyle(.white.opacity(0.68))
                    } else {
                        ForEach(resourceManager.resources) { resource in
                            ResourceRow(
                                resource: resource,
                                onSave: { updatedName, isEnabled, reservationMode, countsTowardQuarterlyDays, maxConsecutiveHours in
                                    await saveResource(
                                        resourceID: resource.id,
                                        name: updatedName,
                                        isEnabled: isEnabled,
                                        reservationMode: reservationMode,
                                        countsTowardQuarterlyDays: countsTowardQuarterlyDays,
                                        maxConsecutiveHours: maxConsecutiveHours
                                    )
                                },
                                onDelete: {
                                    await deleteResource(resourceID: resource.id)
                                }
                            )

                            if resource.id != resourceManager.resources.last?.id {
                                Divider()
                                    .overlay(Color.white.opacity(0.08))
                            }
                        }
                    }

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.72))
                    } else if let errorMessage = resourceManager.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.72))
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
        .navigationTitle("Current Resources")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func saveResource(
        resourceID: String,
        name: String,
        isEnabled: Bool,
        reservationMode: ResourceReservationMode,
        countsTowardQuarterlyDays: Bool,
        maxConsecutiveHours: Int?
    ) async {
        let result = await resourceManager.updateResource(
            id: resourceID,
            name: name,
            isEnabled: isEnabled,
            reservationMode: reservationMode,
            countsTowardQuarterlyDays: countsTowardQuarterlyDays,
            maxConsecutiveHours: reservationMode == .hourly ? maxConsecutiveHours : nil
        )

        switch result {
        case .success:
            message = "Resource updated."
        case .failure(let error):
            message = error.localizedDescription
        }
    }

    private func deleteResource(resourceID: String) async {
        let result = await resourceManager.deleteResource(id: resourceID)

        switch result {
        case .success:
            message = "Resource removed."
        case .failure(let error):
            message = error.localizedDescription
        }
    }
}

private struct ResourceRow: View {
    let resource: ReservableResourceItem
    let onSave: @MainActor (String, Bool, ResourceReservationMode, Bool, Int?) async -> Void
    let onDelete: @MainActor () async -> Void

    @State private var name: String
    @State private var isEnabled: Bool
    @State private var reservationMode: ResourceReservationMode
    @State private var countsTowardQuarterlyDays: Bool
    @State private var maxConsecutiveHoursText: String

    init(
        resource: ReservableResourceItem,
        onSave: @escaping @MainActor (String, Bool, ResourceReservationMode, Bool, Int?) async -> Void,
        onDelete: @escaping @MainActor () async -> Void
    ) {
        self.resource = resource
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: resource.name)
        _isEnabled = State(initialValue: resource.isEnabled)
        _reservationMode = State(initialValue: resource.reservationMode)
        _countsTowardQuarterlyDays = State(initialValue: resource.countsTowardQuarterlyDays)
        _maxConsecutiveHoursText = State(initialValue: resource.maxConsecutiveHours.map(String.init) ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                TextField("Resource name", text: $name)
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .tint(.white)
            }

            Picker("Reservation Mode", selection: $reservationMode) {
                ForEach(ResourceReservationMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .tint(.black)
            .colorScheme(.dark)

            Toggle("Counts toward quarterly days", isOn: $countsTowardQuarterlyDays)
                .tint(.white)

            if reservationMode == .hourly {
                TextField("Optional max hours", text: $maxConsecutiveHoursText)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            HStack(spacing: 12) {
                Button {
                    Task {
                        await onSave(
                            name.trimmingCharacters(in: .whitespacesAndNewlines),
                            isEnabled,
                            reservationMode,
                            countsTowardQuarterlyDays,
                            reservationMode == .hourly ? Int(maxConsecutiveHoursText.trimmingCharacters(in: .whitespacesAndNewlines)) : nil
                        )
                    }
                } label: {
                    Text("Save")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button(role: .destructive) {
                    Task {
                        await onDelete()
                    }
                } label: {
                    Text("Remove")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.18))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        ResourceManagementView()
            .environmentObject(ResourceManager())
    }
}
