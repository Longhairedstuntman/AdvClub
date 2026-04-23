//
//  ContentManagementView.swift
//  AdvClub
//
//  Created by Chase Smith on 4/9/26.
//

import SwiftUI
import FirebaseFirestore
import UniformTypeIdentifiers

struct ContentManagementView: View {
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
            .navigationTitle("Content Management")
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
            Text("Content Management")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Organize how club calendar content and member-created reservations are reviewed and managed.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private var managementOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            NavigationLink {
                ClubContentAdminPage()
            } label: {
                managementCard(
                    title: "Club Content",
                    subtitle: "Review the club calendar entries that admins create and manage.",
                    systemImage: "calendar.badge.clock"
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                MemberContentAdminPage()
            } label: {
                managementCard(
                    title: "Member Content",
                    subtitle: "Review member-created reservations and manage them from one place.",
                    systemImage: "person.text.rectangle"
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                HowToContentAdminPage()
            } label: {
                managementCard(
                    title: "How-To Content",
                    subtitle: "Upload and manage member-facing PDF how-to guides.",
                    systemImage: "doc.richtext"
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

private struct ClubContentAdminPage: View {
    @EnvironmentObject private var calendarEntryManager: CalendarEntryManager

    @State private var message: String?
    @State private var deletingEntryID: String?
    @State private var editingEntry: CalendarEntryRecord?

    private var sortedEntries: [CalendarEntryRecord] {
        calendarEntryManager.entries.sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Club Content")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("These are the admin-created calendar entries that power club events, updates, reservations, and blocks.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Calendar Entries")
                        .font(.title2)
                        .fontWeight(.semibold)

                    if sortedEntries.isEmpty {
                        Text("No club content has been created yet.")
                            .foregroundStyle(.white.opacity(0.68))
                    } else {
                        ForEach(sortedEntries) { entry in
                            clubEntryRow(for: entry)

                            if entry.id != sortedEntries.last?.id {
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

                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(24)
            .foregroundStyle(.white)
        }
        .background(Color.appBackgroundColor)
        .navigationTitle("Club Content")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            calendarEntryManager.startListeningAllEntries()
        }
        .sheet(item: $editingEntry) { entry in
            NavigationStack {
                ClubContentEditorView(entry: entry)
                    .environmentObject(calendarEntryManager)
            }
        }
    }

    private func clubEntryRow(for entry: CalendarEntryRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.title)
                        .font(.headline)

                    Text(entryTypeLabel(for: entry.entryType))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))

                    Text(entryDateText(for: entry))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))

                    if entry.notes.isEmpty == false {
                        Text(entry.notes)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        editingEntry = entry
                    } label: {
                        Text("Edit")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.12))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }

                    Button(role: .destructive) {
                        Task {
                            await deleteCalendarEntry(entryID: entry.id)
                        }
                    } label: {
                        Text(deletingEntryID == entry.id ? "Deleting..." : "Delete")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.18))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .disabled(deletingEntryID == entry.id)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func entryTypeLabel(for type: CalendarEntryType) -> String {
        switch type {
        case .event:
            return "Club Event"
        case .reservation:
            return "Reservation"
        case .block:
            return "Blocked"
        case .update:
            return "Club Update"
        }
    }

    private func entryDateText(for entry: CalendarEntryRecord) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        if entry.isAllDay {
            let start = formatter.string(from: entry.startDate)
            let end = formatter.string(from: entry.endDate)
            return start == end ? start : "\(start) – \(end)"
        }

        if let startTimeText = entry.startTimeText,
           let endTimeText = entry.endTimeText {
            return "\(formatter.string(from: entry.startDate)) • \(startTimeText) – \(endTimeText)"
        }

        return formatter.string(from: entry.startDate)
    }

    private func deleteCalendarEntry(entryID: String) async {
        deletingEntryID = entryID
        defer { deletingEntryID = nil }

        let result = await calendarEntryManager.deleteEntry(entryID: entryID)

        switch result {
        case .success:
            message = "Calendar entry deleted."
        case .failure(let error):
            message = error.localizedDescription
        }
    }
}

private struct MemberContentAdminPage: View {
    @EnvironmentObject private var reservationManager: ReservationManager

    @State private var message: String?
    @State private var deletingReservationID: String?
    @State private var editingReservation: ReservationRecord?

    private var sortedReservations: [ReservationRecord] {
        reservationManager.reservations.sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Member Content")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("These are the member-created reservations currently in the system.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Reservations")
                        .font(.title2)
                        .fontWeight(.semibold)

                    if sortedReservations.isEmpty {
                        Text("No member reservations have been created yet.")
                            .foregroundStyle(.white.opacity(0.68))
                    } else {
                        ForEach(sortedReservations) { reservation in
                            reservationRow(for: reservation)

                            if reservation.id != sortedReservations.last?.id {
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

                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(24)
            .foregroundStyle(.white)
        }
        .background(Color.appBackgroundColor)
        .navigationTitle("Member Content")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            reservationManager.startListeningForVisibleReservations(isAdmin: true)
        }
        .sheet(item: $editingReservation) { reservation in
            NavigationStack {
                AdminReservationContentEditorView(reservation: reservation)
                    .environmentObject(reservationManager)
            }
        }
    }

    private func reservationRow(for reservation: ReservationRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(reservation.title)
                        .font(.headline)

                    Text(reservation.userDisplayName)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))

                    Text(reservation.resourceName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))

                    Text(reservationDateText(for: reservation))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.65))
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        editingReservation = reservation
                    } label: {
                        Text("Edit")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.12))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }

                    Button(role: .destructive) {
                        Task {
                            await deleteReservation(reservationID: reservation.id)
                        }
                    } label: {
                        Text(deletingReservationID == reservation.id ? "Deleting..." : "Delete")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.18))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .disabled(deletingReservationID == reservation.id)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func reservationDateText(for reservation: ReservationRecord) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        if reservation.isAllDay {
            let start = formatter.string(from: reservation.startDate)
            let end = formatter.string(from: reservation.endDate)
            return start == end ? start : "\(start) – \(end)"
        }

        if let startTimeText = reservation.startTimeText,
           let endTimeText = reservation.endTimeText {
            return "\(formatter.string(from: reservation.startDate)) • \(startTimeText) – \(endTimeText)"
        }

        return formatter.string(from: reservation.startDate)
    }

    private func deleteReservation(reservationID: String) async {
        deletingReservationID = reservationID
        defer { deletingReservationID = nil }

        let result = await reservationManager.deleteReservationAsAdmin(reservationID: reservationID)

        switch result {
        case .success:
            message = "Reservation deleted."
        case .failure(let error):
            message = error.localizedDescription
        }
    }
}



private struct ClubContentEditorView: View {
    @EnvironmentObject private var calendarEntryManager: CalendarEntryManager
    @Environment(\.dismiss) private var dismiss

    let entry: CalendarEntryRecord

    @State private var title: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay: Bool
    @State private var startTimeText: String
    @State private var endTimeText: String
    @State private var notes: String
    @State private var isPublished: Bool
    @State private var saveMessage: String?
    @State private var isSaving = false

    init(entry: CalendarEntryRecord) {
        self.entry = entry
        _title = State(initialValue: entry.title)
        _startDate = State(initialValue: entry.startDate)
        _endDate = State(initialValue: entry.endDate)
        _isAllDay = State(initialValue: entry.isAllDay)
        _startTimeText = State(initialValue: entry.startTimeText ?? "9:00 AM")
        _endTimeText = State(initialValue: entry.endTimeText ?? "10:00 AM")
        _notes = State(initialValue: entry.notes)
        _isPublished = State(initialValue: entry.isPublished)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Edit Club Content")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                        TextField("Entry title", text: $title)
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Text(entryTypeLabel(for: entry.entryType))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))

                    if entry.entryType != .update {
                        DatePicker("Start Date", selection: $startDate)
                        DatePicker("End Date", selection: $endDate)
                    }

                    if entry.entryType != .update {
                        Toggle("All Day", isOn: $isAllDay)
                            .tint(.white)
                    }

                    if entry.entryType != .update && isAllDay == false {
                        HStack(spacing: 12) {
                            TextField("Start time", text: $startTimeText)
                                .padding()
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            TextField("End time", text: $endTimeText)
                                .padding()
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                        TextEditor(text: $notes)
                            .frame(minHeight: 120)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(Color(.systemGray5))
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Toggle("Published", isOn: $isPublished)
                        .tint(.white)

                    Button {
                        Task {
                            await saveChanges()
                        }
                    } label: {
                        Text(isSaving ? "Saving..." : "Save Changes")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(isSaving)

                    if let saveMessage {
                        Text(saveMessage)
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
        .navigationTitle("Edit Club Content")
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

    private func entryTypeLabel(for type: CalendarEntryType) -> String {
        switch type {
        case .event:
            return "Club Event"
        case .reservation:
            return "Reservation"
        case .block:
            return "Blocked"
        case .update:
            return "Club Update"
        }
    }

    private func saveChanges() async {
        isSaving = true
        defer { isSaving = false }

        let result = await calendarEntryManager.updateEntry(
            entryID: entry.id,
            title: title,
            entryType: entry.entryType,
            resourceID: entry.resourceID,
            resourceName: entry.resourceName,
            startDate: entry.entryType == .update ? entry.startDate : startDate,
            endDate: entry.entryType == .update ? entry.endDate : endDate,
            isAllDay: entry.entryType == .update ? true : isAllDay,
            startTimeText: entry.entryType == .update ? nil : (isAllDay ? nil : startTimeText),
            endTimeText: entry.entryType == .update ? nil : (isAllDay ? nil : endTimeText),
            notes: notes,
            isPublished: isPublished
        )

        switch result {
        case .success:
            dismiss()
        case .failure(let error):
            saveMessage = error.localizedDescription
        }
    }
}

private struct AdminReservationContentEditorView: View {
    @EnvironmentObject private var reservationManager: ReservationManager
    @Environment(\.dismiss) private var dismiss

    let reservation: ReservationRecord

    @State private var title: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay: Bool
    @State private var startTimeText: String
    @State private var endTimeText: String
    @State private var notes: String
    @State private var status: ReservationStatus
    @State private var saveMessage: String?
    @State private var isSaving = false

    init(reservation: ReservationRecord) {
        self.reservation = reservation
        _title = State(initialValue: reservation.title)
        _startDate = State(initialValue: reservation.startDate)
        _endDate = State(initialValue: reservation.endDate)
        _isAllDay = State(initialValue: reservation.isAllDay)
        _startTimeText = State(initialValue: reservation.startTimeText ?? "9:00 AM")
        _endTimeText = State(initialValue: reservation.endTimeText ?? "10:00 AM")
        _notes = State(initialValue: reservation.notes)
        _status = State(initialValue: reservation.status)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Edit Reservation")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                        TextField("Reservation title", text: $title)
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    DatePicker("Start Date", selection: $startDate)
                    DatePicker("End Date", selection: $endDate)
                    Toggle("All Day", isOn: $isAllDay)
                        .tint(.white)

                    if isAllDay == false {
                        HStack(spacing: 12) {
                            TextField("Start time", text: $startTimeText)
                                .padding()
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            TextField("End time", text: $endTimeText)
                                .padding()
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                        TextEditor(text: $notes)
                            .frame(minHeight: 120)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(Color(.systemGray5))
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Picker("Status", selection: $status) {
                        Text("Pending").tag(ReservationStatus.pending)
                        Text("Confirmed").tag(ReservationStatus.approved)
                        Text("Denied").tag(ReservationStatus.denied)
                        Text("Cancelled").tag(ReservationStatus.cancelled)
                    }
                    .pickerStyle(.segmented)

                    Button {
                        Task {
                            await saveChanges()
                        }
                    } label: {
                        Text(isSaving ? "Saving..." : "Save Changes")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(isSaving)

                    if let saveMessage {
                        Text(saveMessage)
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
        .navigationTitle("Edit Reservation")
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

    private func saveChanges() async {
        isSaving = true
        defer { isSaving = false }

        let result = await reservationManager.updateReservationAsAdmin(
            reservationID: reservation.id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            startTimeText: isAllDay ? nil : startTimeText,
            endTimeText: isAllDay ? nil : endTimeText,
            notes: notes,
            status: status
        )

        switch result {
        case .success:
            dismiss()
        case .failure(let error):
            saveMessage = error.localizedDescription
        }
    }
}


private struct HowToContentAdminPage: View {
    @EnvironmentObject private var howToManager: HowToManager

    @State private var title = ""
    @State private var summary = ""
    @State private var selectedCategory: HowToCategory = .vehicles
    @State private var isPublished = true
    @State private var selectedPDFFileName = ""
    @State private var selectedPDFData: Data?
    @State private var isPresentingPDFImporter = false
    @State private var message: String?
    @State private var isSaving = false
    @State private var deletingHowToID: String?
    @State private var editingHowTo: HowToEntry?

    private var sortedHowTos: [HowToEntry] {
        howToManager.howTos.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("How-To Content")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("Upload PDF how-to guides and manage what members can view inside the app.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }

                createHowToSection
                currentHowTosSection

                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(24)
            .foregroundStyle(.white)
        }
        .background(Color.appBackgroundColor)
        .navigationTitle("How-To Content")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            howToManager.startListeningAllHowTos()
        }
        .fileImporter(
            isPresented: $isPresentingPDFImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handlePDFImport(result)
        }
        .sheet(item: $editingHowTo) { howTo in
            NavigationStack {
                HowToContentEditorView(howTo: howTo)
                    .environmentObject(howToManager)
            }
        }
    }

    private var createHowToSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Upload How-To")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                TextField("Enter title", text: $title)
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Summary")
                TextField("Enter summary", text: $summary)
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                Picker("Category", selection: $selectedCategory) {
                    ForEach(HowToCategory.allCases) { category in
                        Text(category.title).tag(category)
                    }
                }
                .pickerStyle(.segmented)
            }

            Toggle("Published", isOn: $isPublished)
                .tint(.white)

            VStack(alignment: .leading, spacing: 12) {
                Text("PDF File")

                Button {
                    isPresentingPDFImporter = true
                } label: {
                    Text(selectedPDFFileName.isEmpty ? "Choose PDF" : selectedPDFFileName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Button {
                Task {
                    await uploadHowTo()
                }
            } label: {
                Text(isSaving ? "Uploading..." : "Upload How-To")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(isSaving)
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var currentHowTosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current How-Tos")
                .font(.title2)
                .fontWeight(.semibold)

            if sortedHowTos.isEmpty {
                Text("No how-to content has been uploaded yet.")
                    .foregroundStyle(.white.opacity(0.68))
            } else {
                ForEach(sortedHowTos) { howTo in
                    howToRow(for: howTo)

                    if howTo.id != sortedHowTos.last?.id {
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

    private func howToRow(for howTo: HowToEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(howTo.title)
                        .font(.headline)

                    Text(howTo.category.title)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))

                    Text(howTo.summary)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))

                    Text(howTo.isPublished ? "Published" : "Draft")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        editingHowTo = howTo
                    } label: {
                        Text("Edit")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.12))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }

                    Button(role: .destructive) {
                        Task {
                            await deleteHowTo(howToID: howTo.id)
                        }
                    } label: {
                        Text(deletingHowToID == howTo.id ? "Deleting..." : "Delete")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.18))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .disabled(deletingHowToID == howTo.id)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func handlePDFImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let accessGranted = url.startAccessingSecurityScopedResource()
                defer {
                    if accessGranted {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                selectedPDFData = try Data(contentsOf: url)
                selectedPDFFileName = url.lastPathComponent
                message = nil
            } catch {
                message = error.localizedDescription
            }
        case .failure(let error):
            message = error.localizedDescription
        }
    }

    private func uploadHowTo() async {
        guard let selectedPDFData else {
            message = "Choose a PDF before uploading."
            return
        }

        isSaving = true
        defer { isSaving = false }

        let result = await howToManager.createHowTo(
            title: title,
            summary: summary,
            category: selectedCategory,
            isPublished: isPublished,
            pdfData: selectedPDFData,
            pdfFileName: selectedPDFFileName
        )

        switch result {
        case .success:
            title = ""
            summary = ""
            selectedCategory = .vehicles
            isPublished = true
            selectedPDFFileName = ""
            self.selectedPDFData = nil
            message = "How-to uploaded."
        case .failure(let error):
            message = error.localizedDescription
        }
    }

    private func deleteHowTo(howToID: String) async {
        deletingHowToID = howToID
        defer { deletingHowToID = nil }

        let result = await howToManager.deleteHowTo(howToID: howToID)

        switch result {
        case .success:
            message = "How-to deleted."
        case .failure(let error):
            message = error.localizedDescription
        }
    }
}

private struct HowToContentEditorView: View {
    @EnvironmentObject private var howToManager: HowToManager
    @Environment(\.dismiss) private var dismiss

    let howTo: HowToEntry

    @State private var title: String
    @State private var summary: String
    @State private var selectedCategory: HowToCategory
    @State private var isPublished: Bool
    @State private var replacementPDFData: Data?
    @State private var replacementPDFFileName = ""
    @State private var isPresentingPDFImporter = false
    @State private var saveMessage: String?
    @State private var isSaving = false

    init(howTo: HowToEntry) {
        self.howTo = howTo
        _title = State(initialValue: howTo.title)
        _summary = State(initialValue: howTo.summary)
        _selectedCategory = State(initialValue: howTo.category)
        _isPublished = State(initialValue: howTo.isPublished)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Edit How-To")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                        TextField("How-to title", text: $title)
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Summary")
                        TextField("How-to summary", text: $summary)
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                        Picker("Category", selection: $selectedCategory) {
                            ForEach(HowToCategory.allCases) { category in
                                Text(category.title).tag(category)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Toggle("Published", isOn: $isPublished)
                        .tint(.white)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Replace PDF (Optional)")

                        Button {
                            isPresentingPDFImporter = true
                        } label: {
                            Text(replacementPDFFileName.isEmpty ? howTo.pdfFileName : replacementPDFFileName)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        Task {
                            await saveChanges()
                        }
                    } label: {
                        Text(isSaving ? "Saving..." : "Save Changes")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(isSaving)

                    if let saveMessage {
                        Text(saveMessage)
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
        .navigationTitle("Edit How-To")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundStyle(.black)
            }
        }
        .fileImporter(
            isPresented: $isPresentingPDFImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handlePDFImport(result)
        }
    }

    private func handlePDFImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let accessGranted = url.startAccessingSecurityScopedResource()
                defer {
                    if accessGranted {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                replacementPDFData = try Data(contentsOf: url)
                replacementPDFFileName = url.lastPathComponent
                saveMessage = nil
            } catch {
                saveMessage = error.localizedDescription
            }
        case .failure(let error):
            saveMessage = error.localizedDescription
        }
    }

    private func saveChanges() async {
        isSaving = true
        defer { isSaving = false }

        let result = await howToManager.updateHowTo(
            howToID: howTo.id,
            title: title,
            summary: summary,
            category: selectedCategory,
            isPublished: isPublished,
            replacementPDFData: replacementPDFData,
            replacementPDFFileName: replacementPDFFileName.isEmpty ? nil : replacementPDFFileName
        )

        switch result {
        case .success:
            dismiss()
        case .failure(let error):
            saveMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        ContentManagementView()
            .environmentObject(CalendarEntryManager())
            .environmentObject(ReservationManager())
            .environmentObject(HowToManager())
    }
}
