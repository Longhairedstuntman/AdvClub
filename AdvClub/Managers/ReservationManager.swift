//
//  ReservationManager.swift
//  AdvClub
//
//  Created by Chase Smith on 4/16/26.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class ReservationManager: ObservableObject {
    @Published private(set) var reservations: [ReservationRecord] = []
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var reservationsListener: ListenerRegistration?

    deinit {
        reservationsListener?.remove()
    }

    func startListeningForCurrentUserReservations() {
        reservationsListener?.remove()

        guard let currentUserID = Auth.auth().currentUser?.uid else {
            reservations = []
            return
        }

        reservationsListener = db.collection("reservations")
            .whereField("userId", isEqualTo: currentUserID)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }

                    guard let snapshot else {
                        self.reservations = []
                        return
                    }

                    self.reservations = snapshot.documents.compactMap { document in
                        Self.makeReservation(from: document)
                    }
                    .sorted { $0.startDate < $1.startDate }

                    self.errorMessage = nil
                }
            }
    }

    func stopListening() {
        reservationsListener?.remove()
        reservationsListener = nil
    }

    func createReservation(
        title: String,
        resourceID: String,
        resourceName: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        startTimeText: String?,
        endTimeText: String?,
        notes: String,
        reservationMode: ReservationMode = .daily,
        countsTowardQuarterlyDays: Bool = false
    ) async -> Result<ReservationRecord, ReservationError> {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedResourceID = resourceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedResourceName = resourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStartTime = startTimeText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEndTime = endTimeText?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let currentUser = Auth.auth().currentUser else {
            return .failure(.missingAuthenticatedUser)
        }

        guard trimmedTitle.isEmpty == false else {
            return .failure(.missingTitle)
        }

        guard trimmedResourceID.isEmpty == false else {
            return .failure(.missingResource)
        }

        guard trimmedResourceName.isEmpty == false else {
            return .failure(.missingResource)
        }

        guard endDate >= startDate else {
            return .failure(.invalidDateRange)
        }

        let resourceMetadata = await fetchResourceMetadata(resourceID: trimmedResourceID)
        let resolvedReservationMode = resourceMetadata?.reservationMode ?? reservationMode
        let resolvedCountsTowardQuarterlyDays = resourceMetadata?.countsTowardQuarterlyDays ?? countsTowardQuarterlyDays
        let resolvedMaxConsecutiveHours = resourceMetadata?.maxConsecutiveHours

        if isAllDay == false {
            guard let trimmedStartTime, trimmedStartTime.isEmpty == false,
                  let trimmedEndTime, trimmedEndTime.isEmpty == false else {
                return .failure(.missingTimeRange)
            }

            if resolvedReservationMode == .hourly,
               let resolvedMaxConsecutiveHours {
                guard Self.validateHourlyWindow(
                    startTimeText: trimmedStartTime,
                    endTimeText: trimmedEndTime,
                    maxConsecutiveHours: resolvedMaxConsecutiveHours
                ) else {
                    return .failure(.hourlyLimitExceeded(max: resolvedMaxConsecutiveHours))
                }
            }
        }

        do {
            let document = db.collection("reservations").document()
            let record = ReservationRecord(
                id: document.documentID,
                userId: currentUser.uid,
                userEmail: currentUser.email ?? "",
                userDisplayName: currentUser.displayName ?? "",
                resourceID: trimmedResourceID,
                resourceName: trimmedResourceName,
                title: trimmedTitle,
                notes: trimmedNotes,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                startTimeText: isAllDay ? nil : trimmedStartTime,
                endTimeText: isAllDay ? nil : trimmedEndTime,
                reservationMode: resolvedReservationMode,
                countsTowardQuarterlyDays: resolvedCountsTowardQuarterlyDays,
                status: .pending,
                createdAt: Date(),
                updatedAt: Date()
            )

            try await document.setData([
                "userId": record.userId,
                "userEmail": record.userEmail,
                "userDisplayName": record.userDisplayName,
                "resourceID": record.resourceID,
                "resourceName": record.resourceName,
                "title": record.title,
                "notes": record.notes,
                "startDate": Timestamp(date: record.startDate),
                "endDate": Timestamp(date: record.endDate),
                "isAllDay": record.isAllDay,
                "startTimeText": record.startTimeText as Any,
                "endTimeText": record.endTimeText as Any,
                "reservationMode": record.reservationMode.rawValue,
                "countsTowardQuarterlyDays": record.countsTowardQuarterlyDays,
                "status": record.status.rawValue,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
            ])

            return .success(record)
        } catch {
            errorMessage = error.localizedDescription
            return .failure(.backendFailure(error.localizedDescription))
        }
    }

    func currentQuarterUsageSummary(asOf date: Date = Date()) async -> Result<QuarterUsageSummary, ReservationError> {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            return .failure(.missingAuthenticatedUser)
        }

        do {
            let snapshot = try await db.collection("reservations")
                .whereField("userId", isEqualTo: currentUserID)
                .getDocuments()

            let userReservations = snapshot.documents.compactMap { document in
                Self.makeReservation(from: document)
            }

            let summary = Self.computeQuarterUsageSummary(from: userReservations, asOf: date)
            return .success(summary)
        } catch {
            errorMessage = error.localizedDescription
            return .failure(.backendFailure(error.localizedDescription))
        }
    }

    private func fetchResourceMetadata(resourceID: String) async -> ResourceMetadata? {
        do {
            let document = try await db.collection("resources").document(resourceID).getDocument()
            guard let data = document.data() else { return nil }

            let modeRaw = data["reservationMode"] as? String
            let reservationMode = modeRaw.flatMap(ReservationMode.init(rawValue:)) ?? .daily
            let countsTowardQuarterlyDays = data["countsTowardQuarterlyDays"] as? Bool ?? false
            let maxConsecutiveHours = data["maxConsecutiveHours"] as? Int

            return ResourceMetadata(
                reservationMode: reservationMode,
                countsTowardQuarterlyDays: countsTowardQuarterlyDays,
                maxConsecutiveHours: maxConsecutiveHours
            )
        } catch {
            return nil
        }
    }

    private static func validateHourlyWindow(
        startTimeText: String,
        endTimeText: String,
        maxConsecutiveHours: Int
    ) -> Bool {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"

        guard let start = formatter.date(from: startTimeText),
              let end = formatter.date(from: endTimeText) else {
            return false
        }

        let interval = end.timeIntervalSince(start)
        guard interval > 0 else {
            return false
        }

        let hours = interval / 3600
        return hours <= Double(maxConsecutiveHours)
    }

    private static func computeQuarterUsageSummary(
        from reservations: [ReservationRecord],
        asOf date: Date
    ) -> QuarterUsageSummary {
        let currentQuarter = QuarterKey(date: date)
        let previousQuarter = currentQuarter.previousQuarter

        let currentUsed = usedDays(in: currentQuarter, from: reservations)
        let previousUsed = usedDays(in: previousQuarter, from: reservations)

        let previousCarryover = max(0, 30 - previousUsed)
        let totalAvailableThisQuarter = 30 + previousCarryover
        let daysRemainingThisQuarter = max(0, totalAvailableThisQuarter - currentUsed)

        return QuarterUsageSummary(
            currentQuarter: currentQuarter,
            previousQuarter: previousQuarter,
            baseAllowance: 30,
            carryoverFromPreviousQuarter: previousCarryover,
            totalAvailableThisQuarter: totalAvailableThisQuarter,
            usedThisQuarter: currentUsed,
            daysRemainingThisQuarter: daysRemainingThisQuarter
        )
    }

    private static func usedDays(in quarter: QuarterKey, from reservations: [ReservationRecord]) -> Int {
        reservations
            .filter { reservation in
                reservation.countsTowardQuarterlyDays
                && reservation.status != .denied
                && reservation.status != .cancelled
            }
            .reduce(0) { partialResult, reservation in
                partialResult + countedDays(for: reservation, in: quarter)
            }
    }

    private static func countedDays(for reservation: ReservationRecord, in quarter: QuarterKey) -> Int {
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

    private static func makeReservation(from document: DocumentSnapshot) -> ReservationRecord? {
        guard let data = document.data(),
              let userId = data["userId"] as? String,
              let userEmail = data["userEmail"] as? String,
              let userDisplayName = data["userDisplayName"] as? String,
              let resourceID = data["resourceID"] as? String,
              let resourceName = data["resourceName"] as? String,
              let title = data["title"] as? String,
              let notes = data["notes"] as? String,
              let startDate = data["startDate"] as? Timestamp,
              let endDate = data["endDate"] as? Timestamp,
              let isAllDay = data["isAllDay"] as? Bool,
              let reservationModeRaw = data["reservationMode"] as? String,
              let reservationMode = ReservationMode(rawValue: reservationModeRaw),
              let countsTowardQuarterlyDays = data["countsTowardQuarterlyDays"] as? Bool,
              let statusRaw = data["status"] as? String,
              let status = ReservationStatus(rawValue: statusRaw) else {
            return nil
        }

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()

        return ReservationRecord(
            id: document.documentID,
            userId: userId,
            userEmail: userEmail,
            userDisplayName: userDisplayName,
            resourceID: resourceID,
            resourceName: resourceName,
            title: title,
            notes: notes,
            startDate: startDate.dateValue(),
            endDate: endDate.dateValue(),
            isAllDay: isAllDay,
            startTimeText: data["startTimeText"] as? String,
            endTimeText: data["endTimeText"] as? String,
            reservationMode: reservationMode,
            countsTowardQuarterlyDays: countsTowardQuarterlyDays,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct ReservationRecord: Identifiable, Hashable {
    let id: String
    let userId: String
    let userEmail: String
    let userDisplayName: String
    let resourceID: String
    let resourceName: String
    let title: String
    let notes: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let startTimeText: String?
    let endTimeText: String?
    let reservationMode: ReservationMode
    let countsTowardQuarterlyDays: Bool
    let status: ReservationStatus
    let createdAt: Date
    let updatedAt: Date
}

struct QuarterUsageSummary {
    let currentQuarter: QuarterKey
    let previousQuarter: QuarterKey
    let baseAllowance: Int
    let carryoverFromPreviousQuarter: Int
    let totalAvailableThisQuarter: Int
    let usedThisQuarter: Int
    let daysRemainingThisQuarter: Int
}

struct QuarterKey: Hashable {
    let year: Int
    let quarter: Int

    init(date: Date) {
        let calendar = Calendar.current
        year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        switch month {
        case 1...3:
            quarter = 1
        case 4...6:
            quarter = 2
        case 7...9:
            quarter = 3
        default:
            quarter = 4
        }
    }

    var previousQuarter: QuarterKey {
        if quarter == 1 {
            return QuarterKey(year: year - 1, quarter: 4)
        }
        return QuarterKey(year: year, quarter: quarter - 1)
    }

    init(year: Int, quarter: Int) {
        self.year = year
        self.quarter = quarter
    }

    func contains(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let dateYear = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let dateQuarter: Int
        switch month {
        case 1...3:
            dateQuarter = 1
        case 4...6:
            dateQuarter = 2
        case 7...9:
            dateQuarter = 3
        default:
            dateQuarter = 4
        }
        return dateYear == year && dateQuarter == quarter
    }
}

private struct ResourceMetadata {
    let reservationMode: ReservationMode
    let countsTowardQuarterlyDays: Bool
    let maxConsecutiveHours: Int?
}

enum ReservationMode: String, Codable {
    case daily
    case hourly
}

enum ReservationStatus: String, Codable {
    case pending
    case approved
    case denied
    case cancelled
}

enum ReservationError: LocalizedError {
    case missingAuthenticatedUser
    case missingTitle
    case missingResource
    case invalidDateRange
    case missingTimeRange
    case hourlyLimitExceeded(max: Int)
    case backendFailure(String)

    var errorDescription: String? {
        switch self {
        case .missingAuthenticatedUser:
            return "You must be signed in to create a reservation."
        case .missingTitle:
            return "Reservation title is required."
        case .missingResource:
            return "Select a resource before saving the reservation."
        case .invalidDateRange:
            return "The end date must be after the start date."
        case .missingTimeRange:
            return "Start and end times are required for non all-day reservations."
        case .hourlyLimitExceeded(let max):
            return "This hourly reservation is limited to \(max) consecutive hours."
        case .backendFailure(let message):
            return message
        }
    }
}
