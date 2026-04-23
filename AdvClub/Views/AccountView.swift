//
//  AccountView.swift
//  AdvClub
//
//  Created by Chase Smith on 4/9/26.
//

import SwiftUI
import FirebaseFirestore

struct AccountView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var reservationManager: ReservationManager
    @State private var passwordText: String = ""
    @State private var accountMessage: String?
    @State private var usageSummary: QuarterUsageSummary?
    @State private var isPresentingReservationsSheet = false

    private var quarterlyAllowance: Int {
        usageSummary?.totalAvailableThisQuarter ?? 30
    }

    private var usageEntries: [MemberDayUsage] {
        let quarter = usageSummary?.currentQuarter ?? QuarterKey(date: Date())

        return reservationManager.reservations
            .filter { reservation in
                reservation.countsTowardQuarterlyDays
                && reservation.status != .denied
                && reservation.status != .cancelled
                && countedDays(for: reservation, in: quarter) > 0
            }
            .map { reservation in
                MemberDayUsage(
                    id: UUID(),
                    title: reservation.title,
                    usedFor: reservation.resourceName,
                    startDate: reservation.startDate,
                    endDate: reservation.endDate,
                    daysUsed: countedDays(for: reservation, in: quarter)
                )
            }
            .sorted { $0.startDate > $1.startDate }
    }

    private var totalDaysUsed: Int {
        usageSummary?.usedThisQuarter ?? usageEntries.reduce(0) { $0 + $1.daysUsed }
    }

    private var daysLeftThisQuarter: Int {
        usageSummary?.daysRemainingThisQuarter ?? max(quarterlyAllowance - totalDaysUsed, 0)
    }

    private var carryoverText: String {
        guard let usageSummary else {
            return "Usage totals will populate from Firebase reservation history."
        }

        if usageSummary.carryoverFromPreviousQuarter > 0 {
            return "Includes \(usageSummary.carryoverFromPreviousQuarter) carryover day(s) from the previous quarter."
        }

        return "No carryover days from the previous quarter."
    }

    private var usageStatusText: String {
        guard usageSummary != nil else {
            return "Usage history will populate from Firebase reservation history."
        }

        return "Only qualifying vehicle reservations count toward your quarterly days."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                notificationsSection
                daysRemainingSection
                reservationsSection
                accountInfoSection
                logoutSection
            }
            .padding(24)
            .foregroundStyle(.white)
        }
        .background(Color.appBackgroundColor)
        .task {
            reservationManager.startListeningForCurrentUserReservations()
            await refreshUsageSummary()
        }
        .onChange(of: reservationManager.reservations) { _, _ in
            Task {
                await refreshUsageSummary()
            }
        }
        .sheet(isPresented: $isPresentingReservationsSheet) {
            NavigationStack {
                AccountReservationsListView()
                    .environmentObject(reservationManager)
            }
        }
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account Notifications")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Important account notifications, membership updates, billing alerts, and reminders will appear here.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))

            Text("No notifications right now.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.58))
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var daysRemainingSection: some View {
        NavigationLink {
            AccountUsageHistoryView(
                quarterlyAllowance: quarterlyAllowance,
                usageEntries: usageEntries
            )
        } label: {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Days Remaining This Quarter")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    Text("\(daysLeftThisQuarter) of \(quarterlyAllowance) days left")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Tap to view when your days were used, what they were used for, and the dates they were consumed.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))

                    Text(carryoverText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))

                    Text(usageStatusText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text("\(daysLeftThisQuarter)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.white.opacity(0.45))
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
        .buttonStyle(.plain)
    }

    private var reservationsSection: some View {
        Button {
            isPresentingReservationsSheet = true
        } label: {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("My Reservations")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    Text("View your upcoming reservations and the reservations from the last two weeks. Eligible reservations can be cancelled up to the day of the reservation.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(20)
            .background(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var accountInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account Info")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))

                Text(sessionManager.currentUser?.email ?? "No email available")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white.opacity(0.78))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))

                SecureField("Enter a new password", text: $passwordText)
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white)

                Text("Password updates apply to the currently signed-in Firebase account.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }

            Button {
                updatePassword()
            } label: {
                Text("Update Password")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if let accountMessage {
                Text(accountMessage)
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

    private var logoutSection: some View {
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
        .padding(.top, 8)
    }

    private func countedDays(for reservation: ReservationRecord, in quarter: QuarterKey) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: reservation.startDate)
        let end = calendar.startOfDay(for: reservation.endDate)

        guard let daySpan = calendar.dateComponents([.day], from: start, to: end).day else {
            return 0
        }

        var count = 0
        for offset in 0...max(daySpan, 0) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            if quarter.contains(day) {
                count += 1
            }
        }
        return count
    }

    private func refreshUsageSummary() async {
        let result = await reservationManager.currentQuarterUsageSummary()

        switch result {
        case .success(let summary):
            usageSummary = summary
        case .failure:
            usageSummary = nil
        }
    }

    private func updatePassword() {
        guard let currentUser = sessionManager.currentUser else {
            accountMessage = "Unable to load account information."
            return
        }

        let trimmedPassword = passwordText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedPassword.isEmpty == false else {
            accountMessage = "Enter a new password first."
            return
        }

        let result = sessionManager.updateUser(
            userID: currentUser.id,
            email: currentUser.email,
            password: trimmedPassword,
            displayName: currentUser.displayName,
            role: currentUser.role,
            isActive: currentUser.isActive
        )

        switch result {
        case .success:
            accountMessage = "Password update submitted. If Firebase requires recent sign-in, sign out and back in, then try again."
            passwordText = ""
        case .failure(let error):
            accountMessage = error.localizedDescription
        }
    }
}

private struct AccountReservationsListView: View {
    @EnvironmentObject private var reservationManager: ReservationManager
    @Environment(\.dismiss) private var dismiss

    @State private var reservationMessage: String?
    @State private var isCancellingReservationID: String?
    @State private var editingReservation: ReservationRecord?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var visibleReservations: [ReservationRecord] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: todayStart) ?? todayStart

        return reservationManager.reservations
            .filter { $0.endDate >= twoWeeksAgo }
            .sorted { lhs, rhs in
                if lhs.startDate == rhs.startDate {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.startDate > rhs.startDate
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("My Reservations")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("Upcoming reservations are shown here, along with reservations from the last two weeks. Older reservations automatically drop off this list.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }

                if visibleReservations.isEmpty {
                    Text("You do not have any reservations in the current visibility window.")
                        .foregroundStyle(.white.opacity(0.68))
                } else {
                    VStack(spacing: 12) {
                        ForEach(visibleReservations) { reservation in
                            reservationCard(for: reservation)
                        }
                    }
                }

                if let reservationMessage {
                    Text(reservationMessage)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(24)
            .foregroundStyle(.white)
        }
        .background(Color.appBackgroundColor)
        .navigationTitle("My Reservations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundStyle(.black)
            }
        }
        .sheet(item: $editingReservation) { reservation in
            NavigationStack {
                AccountReservationEditorView(reservation: reservation)
                    .environmentObject(reservationManager)
            }
        }
    }

    private func reservationCard(for reservation: ReservationRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reservation.title)
                        .font(.headline)

                    Text(reservation.resourceName)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer()

                Text(statusLabel(for: reservation.status))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusBackground(for: reservation.status))
                    .foregroundStyle(statusForeground(for: reservation.status))
                    .clipShape(Capsule())
            }

            Text(reservationDateText(for: reservation))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))

            if reservation.notes.isEmpty == false {
                Text(reservation.notes)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.65))
            }

            if canCancel(reservation) {
                HStack(spacing: 12) {
                    Button {
                        editingReservation = reservation
                    } label: {
                        Text("Edit")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.12))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Button {
                        Task {
                            await cancelReservation(reservationID: reservation.id)
                        }
                    } label: {
                        Text(isCancellingReservationID == reservation.id ? "Cancelling..." : "Cancel Reservation")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isCancellingReservationID == reservation.id)
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

    private func reservationDateText(for reservation: ReservationRecord) -> String {
        if reservation.isAllDay {
            let start = dateFormatter.string(from: reservation.startDate)
            let end = dateFormatter.string(from: reservation.endDate)
            return start == end ? start : "\(start) – \(end)"
        }

        if let startTimeText = reservation.startTimeText,
           let endTimeText = reservation.endTimeText {
            return "\(dateFormatter.string(from: reservation.startDate)) • \(startTimeText) – \(endTimeText)"
        }

        return dateFormatter.string(from: reservation.startDate)
    }

    private func canCancel(_ reservation: ReservationRecord) -> Bool {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return reservation.status != .cancelled
            && reservation.status != .denied
            && reservation.endDate >= todayStart
    }

    private func statusLabel(for status: ReservationStatus) -> String {
        switch status {
        case .approved:
            return "Confirmed"
        case .pending:
            return "Pending"
        case .denied:
            return "Denied"
        case .cancelled:
            return "Cancelled"
        }
    }

    private func statusBackground(for status: ReservationStatus) -> Color {
        switch status {
        case .approved:
            return .white
        case .pending:
            return Color.white.opacity(0.12)
        case .denied:
            return Color.red.opacity(0.18)
        case .cancelled:
            return Color.white.opacity(0.08)
        }
    }

    private func statusForeground(for status: ReservationStatus) -> Color {
        switch status {
        case .approved:
            return .black
        case .pending, .denied, .cancelled:
            return .white
        }
    }

    private func cancelReservation(reservationID: String) async {
        isCancellingReservationID = reservationID
        defer { isCancellingReservationID = nil }

        let result = await reservationManager.cancelReservation(reservationID: reservationID)

        switch result {
        case .success:
            reservationMessage = "Reservation cancelled."
        case .failure(let error):
            reservationMessage = error.localizedDescription
        }
    }
}



private struct AccountReservationEditorView: View {
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
    }

    private var isHourlyReservation: Bool {
        reservation.reservationMode == .hourly
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Edit Reservation")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("Update this reservation while it is still within the editable window.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                        TextField("Reservation title", text: $title)
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    if isHourlyReservation {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reservation Date")
                            DatePicker("Reservation Date", selection: $startDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(.black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Start Time")
                                TextField("Start time", text: $startTimeText)
                                    .padding()
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("End Time")
                                TextField("End time", text: $endTimeText)
                                    .padding()
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Start Date")
                            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(.black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("End Date")
                            DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(.black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        Toggle("All Day", isOn: $isAllDay)
                            .tint(.white)

                        if isAllDay == false {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Start Time")
                                    TextField("Start time", text: $startTimeText)
                                        .padding()
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("End Time")
                                    TextField("End time", text: $endTimeText)
                                        .padding()
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                        TextEditor(text: $notes)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        .onChange(of: startDate) { _, newValue in
            if isHourlyReservation {
                endDate = newValue
            } else if endDate < newValue {
                endDate = newValue
            }
        }
        .onChange(of: endDate) { _, newValue in
            if isHourlyReservation {
                startDate = newValue
            } else if newValue < startDate {
                startDate = newValue
            }
        }
    }

    private func saveChanges() async {
        isSaving = true
        defer { isSaving = false }

        let result = await reservationManager.updateReservation(
            reservationID: reservation.id,
            title: title,
            startDate: startDate,
            endDate: isHourlyReservation ? startDate : endDate,
            isAllDay: isHourlyReservation ? false : isAllDay,
            startTimeText: (isHourlyReservation || isAllDay == false) ? startTimeText : nil,
            endTimeText: (isHourlyReservation || isAllDay == false) ? endTimeText : nil,
            notes: notes
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
        AccountView()
            .environmentObject(SessionManager())
            .environmentObject(ReservationManager())
    }
}
