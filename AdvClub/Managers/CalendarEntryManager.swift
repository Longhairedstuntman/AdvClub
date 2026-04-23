//
//  CalendarEntryManager.swift
//  AdvClub
//
//  Created by Chase Smith on 4/16/26.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class CalendarEntryManager: ObservableObject {
    @Published private(set) var entries: [CalendarEntryRecord] = []
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var entriesListener: ListenerRegistration?

    deinit {
        entriesListener?.remove()
    }

    func startListeningPublishedEntries() {
        entriesListener?.remove()

        entriesListener = db.collection("calendarEntries")
            .whereField("isPublished", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    print("[CalendarEntryManager] Listener fired for calendarEntries")

                    if let error {
                        print("[CalendarEntryManager] Listener error: \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                        return
                    }

                    guard let snapshot else {
                        print("[CalendarEntryManager] Listener snapshot was nil")
                        self.entries = []
                        return
                    }
                    print("[CalendarEntryManager] Listener document count: \(snapshot.documents.count)")

                    self.entries = snapshot.documents.compactMap { document in
                        Self.makeEntry(from: document)
                    }
                    .sorted { $0.startDate < $1.startDate }

                    self.errorMessage = nil
                }
            }
    }

    func startListeningAllEntries() {
        entriesListener?.remove()

        entriesListener = db.collection("calendarEntries")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }

                    guard let snapshot else {
                        self.entries = []
                        return
                    }

                    self.entries = snapshot.documents.compactMap { document in
                        Self.makeEntry(from: document)
                    }
                    .sorted { $0.startDate > $1.startDate }

                    self.errorMessage = nil
                }
            }
    }

    func stopListening() {
        entriesListener?.remove()
        entriesListener = nil
    }

    func createEntry(
        title: String,
        entryType: CalendarEntryType,
        resourceID: String?,
        resourceName: String?,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        startTimeText: String?,
        endTimeText: String?,
        notes: String,
        isPublished: Bool
    ) async -> Result<CalendarEntryRecord, CalendarEntryError> {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedResourceID = resourceID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedResourceName = resourceName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStartTime = startTimeText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEndTime = endTimeText?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let currentUser = Auth.auth().currentUser else {
            print("[CalendarEntryManager] createEntry failed: no authenticated user")
            return .failure(.missingAuthenticatedUser)
        }

        guard trimmedTitle.isEmpty == false else {
            return .failure(.missingTitle)
        }

        guard endDate >= startDate else {
            return .failure(.invalidDateRange)
        }

        if entryType == .reservation || entryType == .block {
            guard let trimmedResourceID, trimmedResourceID.isEmpty == false,
                  let trimmedResourceName, trimmedResourceName.isEmpty == false else {
                return .failure(.missingResource)
            }
        }

        if isAllDay == false {
            guard let trimmedStartTime, trimmedStartTime.isEmpty == false,
                  let trimmedEndTime, trimmedEndTime.isEmpty == false else {
                return .failure(.missingTimeRange)
            }
        }

        do {
            print("[CalendarEntryManager] Attempting to create calendar entry")
            print("[CalendarEntryManager] title=\(trimmedTitle)")
            print("[CalendarEntryManager] entryType=\(entryType.rawValue)")
            print("[CalendarEntryManager] resourceID=\(trimmedResourceID ?? "nil")")
            print("[CalendarEntryManager] resourceName=\(trimmedResourceName ?? "nil")")
            print("[CalendarEntryManager] isAllDay=\(isAllDay)")
            print("[CalendarEntryManager] isPublished=\(isPublished)")
            print("[CalendarEntryManager] currentUser.uid=\(currentUser.uid)")
            let document = db.collection("calendarEntries").document()
            let record = CalendarEntryRecord(
                id: document.documentID,
                createdByUserID: currentUser.uid,
                createdByEmail: currentUser.email ?? "",
                title: trimmedTitle,
                entryType: entryType,
                resourceID: trimmedResourceID,
                resourceName: trimmedResourceName,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                startTimeText: isAllDay ? nil : trimmedStartTime,
                endTimeText: isAllDay ? nil : trimmedEndTime,
                notes: trimmedNotes,
                isPublished: isPublished,
                createdAt: Date(),
                updatedAt: Date()
            )

            try await document.setData([
                "createdByUserID": record.createdByUserID,
                "createdByEmail": record.createdByEmail,
                "title": record.title,
                "entryType": record.entryType.rawValue,
                "resourceID": record.resourceID as Any,
                "resourceName": record.resourceName as Any,
                "startDate": Timestamp(date: record.startDate),
                "endDate": Timestamp(date: record.endDate),
                "isAllDay": record.isAllDay,
                "startTimeText": record.startTimeText as Any,
                "endTimeText": record.endTimeText as Any,
                "notes": record.notes,
                "isPublished": record.isPublished,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
            ])

            print("[CalendarEntryManager] Successfully created calendar entry with id=\(document.documentID)")
            return .success(record)
        } catch {
            print("[CalendarEntryManager] createEntry error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return .failure(.backendFailure(error.localizedDescription))
        }
    }

    func updateEntry(
        entryID: String,
        title: String,
        entryType: CalendarEntryType,
        resourceID: String?,
        resourceName: String?,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        startTimeText: String?,
        endTimeText: String?,
        notes: String,
        isPublished: Bool
    ) async -> Result<CalendarEntryRecord, CalendarEntryError> {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedResourceID = resourceID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedResourceName = resourceName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStartTime = startTimeText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEndTime = endTimeText?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard Auth.auth().currentUser != nil else {
            return .failure(.missingAuthenticatedUser)
        }

        guard trimmedTitle.isEmpty == false else {
            return .failure(.missingTitle)
        }

        guard endDate >= startDate else {
            return .failure(.invalidDateRange)
        }

        if entryType == .reservation || entryType == .block {
            guard let trimmedResourceID, trimmedResourceID.isEmpty == false,
                  let trimmedResourceName, trimmedResourceName.isEmpty == false else {
                return .failure(.missingResource)
            }
        }

        if isAllDay == false {
            guard let trimmedStartTime, trimmedStartTime.isEmpty == false,
                  let trimmedEndTime, trimmedEndTime.isEmpty == false else {
                return .failure(.missingTimeRange)
            }
        }

        do {
            let document = try await db.collection("calendarEntries").document(entryID).getDocument()
            guard let existingEntry = Self.makeEntry(from: document) else {
                return .failure(.entryNotFound)
            }

            let updatedRecord = CalendarEntryRecord(
                id: entryID,
                createdByUserID: existingEntry.createdByUserID,
                createdByEmail: existingEntry.createdByEmail,
                title: trimmedTitle,
                entryType: entryType,
                resourceID: entryType == .reservation || entryType == .block ? trimmedResourceID : nil,
                resourceName: entryType == .reservation || entryType == .block ? trimmedResourceName : nil,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                startTimeText: isAllDay ? nil : trimmedStartTime,
                endTimeText: isAllDay ? nil : trimmedEndTime,
                notes: trimmedNotes,
                isPublished: isPublished,
                createdAt: existingEntry.createdAt,
                updatedAt: Date()
            )

            try await db.collection("calendarEntries").document(entryID).updateData([
                "title": updatedRecord.title,
                "entryType": updatedRecord.entryType.rawValue,
                "resourceID": updatedRecord.resourceID as Any,
                "resourceName": updatedRecord.resourceName as Any,
                "startDate": Timestamp(date: updatedRecord.startDate),
                "endDate": Timestamp(date: updatedRecord.endDate),
                "isAllDay": updatedRecord.isAllDay,
                "startTimeText": updatedRecord.startTimeText as Any,
                "endTimeText": updatedRecord.endTimeText as Any,
                "notes": updatedRecord.notes,
                "isPublished": updatedRecord.isPublished,
                "updatedAt": FieldValue.serverTimestamp(),
            ])

            return .success(updatedRecord)
        } catch {
            errorMessage = error.localizedDescription
            return .failure(.backendFailure(error.localizedDescription))
        }
    }

    func deleteEntry(entryID: String) async -> Result<Void, CalendarEntryError> {
        guard Auth.auth().currentUser != nil else {
            return .failure(.missingAuthenticatedUser)
        }

        do {
            try await db.collection("calendarEntries").document(entryID).delete()
            return .success(())
        } catch {
            errorMessage = error.localizedDescription
            return .failure(.backendFailure(error.localizedDescription))
        }
    }

    private static func makeEntry(from document: DocumentSnapshot) -> CalendarEntryRecord? {
        guard let data = document.data(),
              let createdByUserID = data["createdByUserID"] as? String,
              let createdByEmail = data["createdByEmail"] as? String,
              let title = data["title"] as? String,
              let entryTypeRaw = data["entryType"] as? String,
              let entryType = CalendarEntryType(rawValue: entryTypeRaw),
              let startDate = data["startDate"] as? Timestamp,
              let endDate = data["endDate"] as? Timestamp,
              let isAllDay = data["isAllDay"] as? Bool,
              let notes = data["notes"] as? String,
              let isPublished = data["isPublished"] as? Bool else {
            return nil
        }

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()

        return CalendarEntryRecord(
            id: document.documentID,
            createdByUserID: createdByUserID,
            createdByEmail: createdByEmail,
            title: title,
            entryType: entryType,
            resourceID: data["resourceID"] as? String,
            resourceName: data["resourceName"] as? String,
            startDate: startDate.dateValue(),
            endDate: endDate.dateValue(),
            isAllDay: isAllDay,
            startTimeText: data["startTimeText"] as? String,
            endTimeText: data["endTimeText"] as? String,
            notes: notes,
            isPublished: isPublished,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct CalendarEntryRecord: Identifiable, Hashable {
    let id: String
    let createdByUserID: String
    let createdByEmail: String
    let title: String
    let entryType: CalendarEntryType
    let resourceID: String?
    let resourceName: String?
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let startTimeText: String?
    let endTimeText: String?
    let notes: String
    let isPublished: Bool
    let createdAt: Date
    let updatedAt: Date
}

enum CalendarEntryType: String, Codable {
    case event
    case reservation
    case block
    case update
}

enum CalendarEntryError: LocalizedError {
    case missingAuthenticatedUser
    case missingTitle
    case missingResource
    case invalidDateRange
    case missingTimeRange
    case entryNotFound
    case backendFailure(String)

    var errorDescription: String? {
        switch self {
        case .missingAuthenticatedUser:
            return "You must be signed in to create a calendar entry."
        case .missingTitle:
            return "A title is required."
        case .missingResource:
            return "Select a resource for reservation or block entries. Club events and updates do not require a resource."
        case .invalidDateRange:
            return "The end date must be after the start date."
        case .missingTimeRange:
            return "Start and end times are required for non all-day entries."
        case .entryNotFound:
            return "The selected calendar entry could not be found."
        case .backendFailure(let message):
            return message
        }
    }
}
