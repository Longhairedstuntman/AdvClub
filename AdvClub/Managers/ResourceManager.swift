//
//  ResourceManager.swift
//  AdvClub
//
//  Created by Chase Smith on 4/14/26.
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class ResourceManager: ObservableObject {
    @Published private(set) var resources: [ReservableResourceItem] = []
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var resourcesListener: ListenerRegistration?

    init() {
        startListening()
    }

    deinit {
        resourcesListener?.remove()
    }

    var enabledResources: [ReservableResourceItem] {
        resources
            .filter(\.isEnabled)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func startListening() {
        resourcesListener?.remove()
        resourcesListener = db.collection("resources")
            .order(by: "name")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }

                    guard let snapshot else {
                        self.resources = []
                        return
                    }

                    self.resources = snapshot.documents.compactMap { document in
                        Self.makeResource(from: document)
                    }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

                    self.errorMessage = nil
                }
            }
    }

    func addResource(
        name: String,
        reservationMode: ResourceReservationMode = .daily,
        countsTowardQuarterlyDays: Bool = false,
        maxConsecutiveHours: Int? = nil,
        isEnabled: Bool = true
    ) async -> Result<ReservableResourceItem, ResourceError> {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedName.isEmpty == false else {
            return .failure(.missingName)
        }

        guard resources.contains(where: { $0.name.compare(trimmedName, options: .caseInsensitive) == .orderedSame }) == false else {
            return .failure(.duplicateName)
        }

        if reservationMode == .hourly,
           let maxConsecutiveHours,
           maxConsecutiveHours <= 0 {
            return .failure(.invalidMaxConsecutiveHours)
        }

        do {
            let normalizedName = trimmedName
            let document = db.collection("resources").document()

            try await document.setData([
                "name": normalizedName,
                "isEnabled": isEnabled,
                "reservationMode": reservationMode.rawValue,
                "countsTowardQuarterlyDays": countsTowardQuarterlyDays,
                "maxConsecutiveHours": maxConsecutiveHours as Any,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
            ])

            let resource = ReservableResourceItem(
                id: document.documentID,
                name: normalizedName,
                isEnabled: isEnabled,
                reservationMode: reservationMode,
                countsTowardQuarterlyDays: countsTowardQuarterlyDays,
                maxConsecutiveHours: maxConsecutiveHours
            )

            return .success(resource)
        } catch {
            errorMessage = error.localizedDescription
            return .failure(.backendFailure(error.localizedDescription))
        }
    }

    func updateResource(
        id: String,
        name: String,
        isEnabled: Bool,
        reservationMode: ResourceReservationMode? = nil,
        countsTowardQuarterlyDays: Bool? = nil,
        maxConsecutiveHours: Int? = nil
    ) async -> Result<Void, ResourceError> {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedName.isEmpty == false else {
            return .failure(.missingName)
        }

        guard resources.contains(where: {
            $0.id != id && $0.name.compare(trimmedName, options: .caseInsensitive) == .orderedSame
        }) == false else {
            return .failure(.duplicateName)
        }

        guard let existingResource = resources.first(where: { $0.id == id }) else {
            return .failure(.resourceNotFound)
        }

        let resolvedReservationMode = reservationMode ?? existingResource.reservationMode
        let resolvedCountsTowardQuarterlyDays = countsTowardQuarterlyDays ?? existingResource.countsTowardQuarterlyDays
        let resolvedMaxConsecutiveHours = resolvedReservationMode == .hourly
            ? (maxConsecutiveHours ?? existingResource.maxConsecutiveHours)
            : nil

        if resolvedReservationMode == .hourly,
           let resolvedMaxConsecutiveHours,
           resolvedMaxConsecutiveHours <= 0 {
            return .failure(.invalidMaxConsecutiveHours)
        }

        do {
            try await db.collection("resources").document(id).updateData([
                "name": trimmedName,
                "isEnabled": isEnabled,
                "reservationMode": resolvedReservationMode.rawValue,
                "countsTowardQuarterlyDays": resolvedCountsTowardQuarterlyDays,
                "maxConsecutiveHours": resolvedMaxConsecutiveHours as Any,
                "updatedAt": FieldValue.serverTimestamp(),
            ])
            return .success(())
        } catch {
            errorMessage = error.localizedDescription
            return .failure(.backendFailure(error.localizedDescription))
        }
    }

    func deleteResource(id: String) async -> Result<Void, ResourceError> {
        do {
            try await db.collection("resources").document(id).delete()
            return .success(())
        } catch {
            errorMessage = error.localizedDescription
            return .failure(.backendFailure(error.localizedDescription))
        }
    }

    func seedDefaultResourcesIfNeeded() async -> Result<Void, ResourceError> {
        if resources.isEmpty == false {
            return .success(())
        }

        let defaults: [SeedResource] = [
            SeedResource(name: "Cars", reservationMode: .daily, countsTowardQuarterlyDays: true, maxConsecutiveHours: nil),
            SeedResource(name: "Boats", reservationMode: .daily, countsTowardQuarterlyDays: true, maxConsecutiveHours: nil),
            SeedResource(name: "Garage", reservationMode: .daily, countsTowardQuarterlyDays: false, maxConsecutiveHours: nil),
            SeedResource(name: "Car Simulators", reservationMode: .hourly, countsTowardQuarterlyDays: false, maxConsecutiveHours: nil),
            SeedResource(name: "Golf Simulator", reservationMode: .hourly, countsTowardQuarterlyDays: false, maxConsecutiveHours: 5),
        ]

        do {
            let batch = db.batch()

            for resource in defaults {
                let document = db.collection("resources").document()
                batch.setData([
                    "name": resource.name,
                    "isEnabled": true,
                    "reservationMode": resource.reservationMode.rawValue,
                    "countsTowardQuarterlyDays": resource.countsTowardQuarterlyDays,
                    "maxConsecutiveHours": resource.maxConsecutiveHours as Any,
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp(),
                ], forDocument: document)
            }

            try await batch.commit()
            return .success(())
        } catch {
            errorMessage = error.localizedDescription
            return .failure(.backendFailure(error.localizedDescription))
        }
    }

    private static func makeResource(from document: DocumentSnapshot) -> ReservableResourceItem? {
        guard let data = document.data(),
              let name = data["name"] as? String,
              let isEnabled = data["isEnabled"] as? Bool else {
            return nil
        }

        let legacyDefaults = legacyDefaults(for: name)
        let reservationModeRaw = data["reservationMode"] as? String
        let reservationMode = reservationModeRaw.flatMap(ResourceReservationMode.init(rawValue:)) ?? legacyDefaults.reservationMode
        let countsTowardQuarterlyDays = data["countsTowardQuarterlyDays"] as? Bool ?? legacyDefaults.countsTowardQuarterlyDays
        let maxConsecutiveHours = data["maxConsecutiveHours"] as? Int ?? legacyDefaults.maxConsecutiveHours

        return ReservableResourceItem(
            id: document.documentID,
            name: name,
            isEnabled: isEnabled,
            reservationMode: reservationMode,
            countsTowardQuarterlyDays: countsTowardQuarterlyDays,
            maxConsecutiveHours: reservationMode == .hourly ? maxConsecutiveHours : nil
        )
    }

    private static func legacyDefaults(for name: String) -> SeedResource {
        let normalizedName = name.lowercased()

        if normalizedName == "golf simulator" {
            return SeedResource(name: name, reservationMode: .hourly, countsTowardQuarterlyDays: false, maxConsecutiveHours: 5)
        }

        if normalizedName == "car simulators" {
            return SeedResource(name: name, reservationMode: .hourly, countsTowardQuarterlyDays: false, maxConsecutiveHours: nil)
        }

        if normalizedName == "cars" || normalizedName == "boats" || normalizedName == "side by sides" || normalizedName == "side-by-sides" {
            return SeedResource(name: name, reservationMode: .daily, countsTowardQuarterlyDays: true, maxConsecutiveHours: nil)
        }

        return SeedResource(name: name, reservationMode: .daily, countsTowardQuarterlyDays: false, maxConsecutiveHours: nil)
    }
}

struct ReservableResourceItem: Identifiable, Hashable {
    let id: String
    var name: String
    var isEnabled: Bool
    var reservationMode: ResourceReservationMode
    var countsTowardQuarterlyDays: Bool
    var maxConsecutiveHours: Int?
}

enum ResourceReservationMode: String, Codable, CaseIterable, Identifiable {
    case daily
    case hourly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily:
            return "Daily"
        case .hourly:
            return "Hourly"
        }
    }
}

private struct SeedResource {
    let name: String
    let reservationMode: ResourceReservationMode
    let countsTowardQuarterlyDays: Bool
    let maxConsecutiveHours: Int?
}

enum ResourceError: LocalizedError {
    case missingName
    case duplicateName
    case resourceNotFound
    case invalidMaxConsecutiveHours
    case backendFailure(String)

    var errorDescription: String? {
        switch self {
        case .missingName:
            return "Resource name is required."
        case .duplicateName:
            return "A resource with that name already exists."
        case .resourceNotFound:
            return "The selected resource could not be found."
        case .invalidMaxConsecutiveHours:
            return "Max consecutive hours must be greater than zero for hourly resources."
        case .backendFailure(let message):
            return message
        }
    }
}
