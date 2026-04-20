//
//  ContentView.swift
//  AdvClub
//
//  Created by Chase Smith on 4/6/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var resourceManager: ResourceManager
    @EnvironmentObject private var reservationManager: ReservationManager
    @State private var isPresentingQuickReservationForm = false

    var body: some View {
        Group {
            if sessionManager.isAuthenticated {
                TabView {
                    tabRoot {
                        HomeView()
                            .appHeader()
                    }
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }

                    tabRoot {
                        CarsView()
                            .appHeader()
                    }
                    .tabItem {
                        Label("Cars", systemImage: "car")
                    }

                    tabRoot {
                        HowToView()
                            .appHeader()
                    }
                    .tabItem {
                        Label("How To", systemImage: "doc.text")
                    }

                    tabRoot {
                        CalendarView()
                            .appHeader()
                    }
                    .tabItem {
                        Label("Calendar", systemImage: "calendar")
                    }

                    tabRoot {
                        AccountView()
                            .appHeader()
                    }
                    .tabItem {
                        Label("Account", systemImage: "person.crop.circle")
                    }

                    if sessionManager.isAdmin {
                        tabRoot {
                            AdminView()
                                .appHeader()
                        }
                        .tabItem {
                            Label("Admin", systemImage: "lock.shield")
                        }
                    }
                }
                .tint(.white)
                .sheet(isPresented: $isPresentingQuickReservationForm) {
                    GlobalReservationEntrySheet()
                        .environmentObject(resourceManager)
                        .environmentObject(reservationManager)
                }
            } else {
                LoginView()
            }
        }
    }

    private func tabRoot<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingQuickReservationForm = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Create reservation")
            }
        }
    }
}

private struct GlobalReservationEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var resourceManager: ResourceManager
    @EnvironmentObject private var reservationManager: ReservationManager

    @State private var reservationTitle = ""
    @State private var selectedReservationType: MemberReservationType = .resource
    @State private var selectedResourceID: String = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isAllDay = true
    @State private var startTime = "9:00 AM"
    @State private var endTime = "5:00 PM"
    @State private var notes = ""
    @State private var isSaving = false
    @State private var message: String?

    private var selectedResource: ReservableResourceItem? {
        enabledResources.first(where: { $0.id == selectedResourceID })
    }

    private var selectedReservationMode: ReservationMode {
        guard let selectedResource else { return .daily }
        return selectedResource.name == "Golf Simulator" ? .hourly : .daily
    }

    private var countsTowardQuarterlyDays: Bool {
        guard let selectedResource else { return false }

        let normalizedName = selectedResource.name.lowercased()
        return normalizedName == "car"
            || normalizedName == "cars"
            || normalizedName == "boat"
            || normalizedName == "boats"
            || normalizedName == "side by side"
            || normalizedName == "side-by-side"
            || normalizedName == "side by sides"
            || normalizedName == "side-by-sides"
    }

    private var enabledResources: [ReservableResourceItem] {
        resourceManager.enabledResources
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                reservationFormContent
                    .padding(24)
            }
            .navigationTitle("Add Reservation")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if selectedResourceID.isEmpty {
                    selectedResourceID = enabledResources.first?.id ?? ""
                }
            }
            .onChange(of: enabledResources) { _, newResources in
                if newResources.contains(where: { $0.id == selectedResourceID }) == false {
                    selectedResourceID = newResources.first?.id ?? ""
                }
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

    private var reservationFormContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            reservationHeaderSection
            reservationTitleSection
            reservationTypeSection

            if selectedReservationType == .resource {
                resourcePickerSection
            }

            reservationStartDateSection
            reservationEndDateSection
            allDayToggleSection

            if isAllDay == false {
                reservationTimeSection
            }

            reservationNotesSection
            reservationActionSection
        }
    }

    private var reservationHeaderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Create Reservation")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Quick reservation entry available from every page.")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var reservationTitleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reservation Title")
                .font(.subheadline.weight(.semibold))

            TextField("Enter reservation title", text: $reservationTitle)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var reservationTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Request Type")
                .font(.subheadline.weight(.semibold))

            Picker("Request Type", selection: $selectedReservationType) {
                ForEach(MemberReservationType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var resourcePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What would you like to reserve?")
                .font(.subheadline.weight(.semibold))

            if enabledResources.isEmpty {
                Text("No reservable resources are currently available.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                Picker("Resource", selection: $selectedResourceID) {
                    ForEach(enabledResources) { resource in
                        Text(resource.name).tag(resource.id)
                    }
                }
                .pickerStyle(.menu)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var reservationStartDateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start Date")
                .font(.subheadline.weight(.semibold))

            DatePicker(
                "Start Date",
                selection: $startDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .tint(.black)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var reservationEndDateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("End Date")
                .font(.subheadline.weight(.semibold))

            DatePicker(
                "End Date",
                selection: $endDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .tint(.black)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var allDayToggleSection: some View {
        Toggle("All Day", isOn: $isAllDay)
            .tint(.black)
    }

    private var reservationTimeSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Start Time")
                    .font(.subheadline.weight(.semibold))

                TextField("Start time", text: $startTime)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("End Time")
                    .font(.subheadline.weight(.semibold))

                TextField("End time", text: $endTime)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var reservationNotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.subheadline.weight(.semibold))

            TextEditor(text: $notes)
                .foregroundStyle(.black)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var reservationActionSection: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await saveReservation()
                }
            } label: {
                Text(isSaving ? "Saving..." : "Save Reservation")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(isSaving || selectedResource == nil)

            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private func saveReservation() async {
        guard let selectedResource else {
            message = "Select a resource before saving the reservation."
            return
        }

        isSaving = true
        defer { isSaving = false }

        let result = await reservationManager.createReservation(
            title: reservationTitle,
            resourceID: selectedResource.id,
            resourceName: selectedResource.name,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            startTimeText: isAllDay ? nil : startTime,
            endTimeText: isAllDay ? nil : endTime,
            notes: notes,
            reservationMode: selectedReservationMode,
            countsTowardQuarterlyDays: countsTowardQuarterlyDays
        )

        switch result {
        case .success:
            dismiss()
        case .failure(let error):
            message = error.localizedDescription
        }
    }
}

private enum MemberReservationType: String, CaseIterable, Identifiable {
    case resource

    var id: String { rawValue }

    var title: String {
        switch self {
        case .resource:
            return "Reserve"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SessionManager())
        .environmentObject(ResourceManager())
        .environmentObject(ReservationManager())
}
