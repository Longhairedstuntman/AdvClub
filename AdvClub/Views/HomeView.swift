//
//  HomeView.swift
//  AdvClub
//
//  Created by Chase Smith on 4/9/26.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var clubContentManager: ClubContentManager
    @EnvironmentObject private var calendarEntryManager: CalendarEntryManager
    @EnvironmentObject private var reservationManager: ReservationManager

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private let dayOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var upcomingClubEvent: CalendarEntryRecord? {
        calendarEntryManager.entries
            .filter { $0.entryType == .event && $0.endDate >= Date() }
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    private var homeFeedEntries: [CalendarEntryRecord] {
        calendarEntryManager.entries
            .filter { entry in
                switch entry.entryType {
                case .event:
                    return entry.endDate >= Calendar.current.startOfDay(for: Date())
                case .update:
                    return true
                case .reservation, .block:
                    return false
                }
            }
            .sorted { lhs, rhs in
                if lhs.entryType == rhs.entryType {
                    return lhs.startDate < rhs.startDate
                }

                if lhs.entryType == .update {
                    return false
                }

                if rhs.entryType == .update {
                    return true
                }

                return lhs.startDate < rhs.startDate
            }
    }

    private var upcomingReservations: [ReservationRecord] {
        reservationManager.reservations
            .filter { reservation in
                reservation.status != .denied
                && reservation.status != .cancelled
                && reservation.endDate >= Calendar.current.startOfDay(for: Date())
            }
            .sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                spotlightSection

                VStack(spacing: 20) {
                    eventsAndUpdatesSection
                    upcomingReservationsSection
                }
            }
            .padding(20)
        }
        .background(Color.appBackgroundColor)
        .foregroundStyle(.white)
        .task {
            calendarEntryManager.startListeningPublishedEntries()
            reservationManager.startListeningForCurrentUserReservations()
        }
    }

    private var spotlightSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SPOTLIGHT")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.72))

            if let event = upcomingClubEvent {
                Text(event.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                Text(dateFormatter.string(from: event.startDate))
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.82))

                Text(event.notes.isEmpty ? "Upcoming club event." : event.notes)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.72))

                HStack(spacing: 12) {
                    chip(text: "Club Event")
                    chip(text: "Upcoming")
                }
            } else {
                Text("No spotlighted content yet.")
                    .font(.headline)

                Text("Once an admin adds an upcoming club event, it will appear here.")
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var eventsAndUpdatesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Events & Club Updates")
                .font(.title2)
                .fontWeight(.semibold)

            if homeFeedEntries.isEmpty {
                Text("No events or club updates have been published yet.")
                    .foregroundStyle(.white.opacity(0.68))
            } else {
                ForEach(homeFeedEntries.prefix(6)) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(entry.title)
                                .font(.headline)

                            Spacer()

                            Text(entry.entryType == .update ? "Club Update" : "Club Event")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Capsule())
                        }

                        if entry.entryType == .event {
                            Text(dateFormatter.string(from: entry.startDate))
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        Text(entry.notes.isEmpty ? (entry.entryType == .update ? "Club update." : "Upcoming club event.") : entry.notes)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)

                    if entry.id != homeFeedEntries.prefix(6).last?.id {
                        Divider()
                            .overlay(Color.white.opacity(0.08))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(20)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var upcomingReservationsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Upcoming Reservations")
                .font(.title2)
                .fontWeight(.semibold)

            if upcomingReservations.isEmpty {
                Text("You do not have any upcoming reservations.")
                    .foregroundStyle(.white.opacity(0.68))
            } else {
                VStack(spacing: 12) {
                    ForEach(upcomingReservations.prefix(4)) { reservation in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reservation.title)
                                    .font(.headline)

                                Text(reservationDateText(for: reservation))
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.68))

                                Text(reservation.resourceName)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }

                            Spacer()

                            Text(statusText(for: reservation.status))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(statusBackground(for: reservation.status))
                                .foregroundStyle(statusForeground(for: reservation.status))
                                .clipShape(Capsule())
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
            let start = dayOnlyFormatter.string(from: reservation.startDate)
            let end = dayOnlyFormatter.string(from: reservation.endDate)
            return start == end ? start : "\(start) – \(end)"
        }

        if let startTimeText = reservation.startTimeText,
           let endTimeText = reservation.endTimeText {
            return "\(dayOnlyFormatter.string(from: reservation.startDate)) • \(startTimeText) – \(endTimeText)"
        }

        return dayOnlyFormatter.string(from: reservation.startDate)
    }

    private func statusText(for status: ReservationStatus) -> String {
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

    private func chip(text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.1))
            .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(ClubContentManager())
            .environmentObject(CalendarEntryManager())
            .environmentObject(ReservationManager())
    }
}
