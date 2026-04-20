//
//  AccountView.swift
//  AdvClub
//
//  Created by Chase Smith on 4/9/26.
//

import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var reservationManager: ReservationManager
    @State private var passwordText: String = ""
    @State private var accountMessage: String?
    @State private var usageSummary: QuarterUsageSummary?

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

#Preview {
    NavigationStack {
        AccountView()
            .environmentObject(SessionManager())
            .environmentObject(ReservationManager())
    }
}
