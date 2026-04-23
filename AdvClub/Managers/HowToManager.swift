//
//  HowToManager.swift
//  AdvClub
//
//  Created by Chase Smith on 4/21/26.
//

import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

final class HowToManager: ObservableObject {
    @Published private(set) var howTos: [HowToEntry] = []
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var howTosListener: ListenerRegistration?

    deinit {
        howTosListener?.remove()
    }

    func stopListening() {
        howTosListener?.remove()
        howTosListener = nil
    }

    func startListeningPublishedHowTos() {
        howTosListener?.remove()

        howTosListener = db.collection("howTos")
            .whereField("isPublished", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }

                    guard let snapshot else {
                        self.howTos = []
                        return
                    }

                    self.howTos = snapshot.documents.compactMap { document in
                        Self.makeHowTo(from: document)
                    }
                    .sorted { lhs, rhs in
                        if lhs.category == rhs.category {
                            return lhs.title < rhs.title
                        }
                        return lhs.createdAt > rhs.createdAt
                    }

                    self.errorMessage = nil
                }
            }
    }

    func startListeningAllHowTos() {
        howTosListener?.remove()

        howTosListener = db.collection("howTos")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }

                    guard let snapshot else {
                        self.howTos = []
                        return
                    }

                    self.howTos = snapshot.documents.compactMap { document in
                        Self.makeHowTo(from: document)
                    }
                    .sorted { lhs, rhs in
                        if lhs.category == rhs.category {
                            return lhs.title < rhs.title
                        }
                        return lhs.createdAt > rhs.createdAt
                    }

                    self.errorMessage = nil
                }
            }
    }

    func createHowTo(
        title: String,
        summary: String,
        category: HowToCategory,
        isPublished: Bool,
        pdfData: Data,
        pdfFileName: String
    ) async -> Result<HowToEntry, HowToError> {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPDFFileName = pdfFileName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let currentUser = Auth.auth().currentUser else {
            return .failure(.missingAuthenticatedUser)
        }

        guard trimmedTitle.isEmpty == false else {
            return .failure(.missingTitle)
        }

        guard trimmedSummary.isEmpty == false else {
            return .failure(.missingSummary)
        }

        guard trimmedPDFFileName.isEmpty == false else {
            return .failure(.missingPDFFile)
        }

        let document = db.collection("howTos").document()
        let safeFileName = sanitizePDFFileName(trimmedPDFFileName)
        let pdfStoragePath = "howTos/\(document.documentID)-\(safeFileName)"

        do {
            let pdfDownloadURL = try await uploadPDF(data: pdfData, storagePath: pdfStoragePath)

            let record = HowToEntry(
                id: document.documentID,
                title: trimmedTitle,
                summary: trimmedSummary,
                category: category,
                pdfFileName: safeFileName,
                pdfStoragePath: pdfStoragePath,
                pdfDownloadURL: pdfDownloadURL.absoluteString,
                isPublished: isPublished,
                createdByUserID: currentUser.uid,
                createdByEmail: currentUser.email ?? "",
                createdAt: Date(),
                updatedAt: Date()
            )

            try await document.setData([
                "title": record.title,
                "summary": record.summary,
                "category": record.category.rawValue,
                "pdfFileName": record.pdfFileName,
                "pdfStoragePath": record.pdfStoragePath,
                "pdfDownloadURL": record.pdfDownloadURL,
                "isPublished": record.isPublished,
                "createdByUserID": record.createdByUserID,
                "createdByEmail": record.createdByEmail,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
            ])

            return .success(record)
        } catch {
            errorMessage = error.localizedDescription
            return .failure(.backendFailure(error.localizedDescription))
        }
    }

    func updateHowTo(
        howToID: String,
        title: String,
        summary: String,
        category: HowToCategory,
        isPublished: Bool,
        replacementPDFData: Data? = nil,
        replacementPDFFileName: String? = nil
    ) async -> Result<HowToEntry, HowToError> {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReplacementFileName = replacementPDFFileName?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard Auth.auth().currentUser != nil else {
            return .failure(.missingAuthenticatedUser)
        }

        guard trimmedTitle.isEmpty == false else {
            return .failure(.missingTitle)
        }

        guard trimmedSummary.isEmpty == false else {
            return .failure(.missingSummary)
        }

        do {
            let document = try await db.collection("howTos").document(howToID).getDocument()
            guard let existingHowTo = Self.makeHowTo(from: document) else {
                return .failure(.howToNotFound)
            }

            var pdfFileName = existingHowTo.pdfFileName
            var pdfStoragePath = existingHowTo.pdfStoragePath
            var pdfDownloadURL = existingHowTo.pdfDownloadURL

            if let replacementPDFData {
                let resolvedFileName = sanitizePDFFileName(
                    (trimmedReplacementFileName?.isEmpty == false ? trimmedReplacementFileName! : existingHowTo.pdfFileName)
                )
                let resolvedStoragePath = "howTos/\(howToID)-\(resolvedFileName)"
                let downloadURL = try await uploadPDF(data: replacementPDFData, storagePath: resolvedStoragePath)

                pdfFileName = resolvedFileName
                pdfStoragePath = resolvedStoragePath
                pdfDownloadURL = downloadURL.absoluteString
            }

            let updatedHowTo = HowToEntry(
                id: howToID,
                title: trimmedTitle,
                summary: trimmedSummary,
                category: category,
                pdfFileName: pdfFileName,
                pdfStoragePath: pdfStoragePath,
                pdfDownloadURL: pdfDownloadURL,
                isPublished: isPublished,
                createdByUserID: existingHowTo.createdByUserID,
                createdByEmail: existingHowTo.createdByEmail,
                createdAt: existingHowTo.createdAt,
                updatedAt: Date()
            )

            try await db.collection("howTos").document(howToID).updateData([
                "title": updatedHowTo.title,
                "summary": updatedHowTo.summary,
                "category": updatedHowTo.category.rawValue,
                "pdfFileName": updatedHowTo.pdfFileName,
                "pdfStoragePath": updatedHowTo.pdfStoragePath,
                "pdfDownloadURL": updatedHowTo.pdfDownloadURL,
                "isPublished": updatedHowTo.isPublished,
                "updatedAt": FieldValue.serverTimestamp(),
            ])

            return .success(updatedHowTo)
        } catch {
            errorMessage = error.localizedDescription
            return .failure(.backendFailure(error.localizedDescription))
        }
    }

    func deleteHowTo(howToID: String) async -> Result<Void, HowToError> {
        guard Auth.auth().currentUser != nil else {
            return .failure(.missingAuthenticatedUser)
        }

        do {
            let document = try await db.collection("howTos").document(howToID).getDocument()
            if let existingHowTo = Self.makeHowTo(from: document) {
                let storageRef = storage.reference(withPath: existingHowTo.pdfStoragePath)
                try await storageRef.delete()
            }

            try await db.collection("howTos").document(howToID).delete()
            return .success(())
        } catch {
            errorMessage = error.localizedDescription
            return .failure(.backendFailure(error.localizedDescription))
        }
    }

    private func uploadPDF(data: Data, storagePath: String) async throws -> URL {
        let storageRef = storage.reference(withPath: storagePath)
        let metadata = StorageMetadata()
        metadata.contentType = "application/pdf"

        _ = try await storageRef.putDataAsync(data, metadata: metadata)
        return try await storageRef.downloadURL()
    }

    private func sanitizePDFFileName(_ fileName: String) -> String {
        let lowercased = fileName.lowercased()
        let dashed = lowercased.replacingOccurrences(of: " ", with: "-")
        if dashed.hasSuffix(".pdf") {
            return dashed
        }
        return dashed + ".pdf"
    }

    private static func makeHowTo(from document: DocumentSnapshot) -> HowToEntry? {
        guard let data = document.data(),
              let title = data["title"] as? String,
              let summary = data["summary"] as? String,
              let categoryRawValue = data["category"] as? String,
              let category = HowToCategory(rawValue: categoryRawValue),
              let pdfFileName = data["pdfFileName"] as? String,
              let pdfStoragePath = data["pdfStoragePath"] as? String,
              let pdfDownloadURL = data["pdfDownloadURL"] as? String,
              let isPublished = data["isPublished"] as? Bool,
              let createdByUserID = data["createdByUserID"] as? String,
              let createdByEmail = data["createdByEmail"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let updatedAtTimestamp = data["updatedAt"] as? Timestamp else {
            return nil
        }

        return HowToEntry(
            id: document.documentID,
            title: title,
            summary: summary,
            category: category,
            pdfFileName: pdfFileName,
            pdfStoragePath: pdfStoragePath,
            pdfDownloadURL: pdfDownloadURL,
            isPublished: isPublished,
            createdByUserID: createdByUserID,
            createdByEmail: createdByEmail,
            createdAt: createdAtTimestamp.dateValue(),
            updatedAt: updatedAtTimestamp.dateValue()
        )
    }
}

enum HowToCategory: String, CaseIterable, Identifiable, Codable {
    case vehicles
    case adventureClub
    case misc

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vehicles:
            return "Vehicles"
        case .adventureClub:
            return "Adventure Club"
        case .misc:
            return "Misc"
        }
    }

    var iconName: String {
        switch self {
        case .vehicles:
            return "car.fill"
        case .adventureClub:
            return "mountain.2.fill"
        case .misc:
            return "square.grid.2x2.fill"
        }
    }
}

struct HowToEntry: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var summary: String
    var category: HowToCategory
    var pdfFileName: String
    var pdfStoragePath: String
    var pdfDownloadURL: String
    var isPublished: Bool
    var createdByUserID: String
    var createdByEmail: String
    var createdAt: Date
    var updatedAt: Date
}

enum HowToError: LocalizedError {
    case missingAuthenticatedUser
    case missingTitle
    case missingSummary
    case missingPDFFile
    case howToNotFound
    case backendFailure(String)

    var errorDescription: String? {
        switch self {
        case .missingAuthenticatedUser:
            return "You must be signed in to manage how-to content."
        case .missingTitle:
            return "A title is required."
        case .missingSummary:
            return "A summary is required."
        case .missingPDFFile:
            return "A PDF file is required."
        case .howToNotFound:
            return "The selected how-to entry could not be found."
        case .backendFailure(let message):
            return message
        }
    }
}
