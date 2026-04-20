//
//  AdminSecurityManager.swift
//  AdvClub
//
//  Created by Chase Smith on 4/6/26.
//

import Foundation
import Security
import SwiftUI
import Combine

@MainActor
final class AdminSecurityManager: ObservableObject {
    @Published private(set) var isUnlocked = false

    private let service = "com.advclub.admin"
    private let account = "admin_pin"
    private let unlockDuration: TimeInterval = 5 * 60

    private var unlockExpirationDate: Date?

    init() {
        seedDefaultPINIfNeeded()
        refreshUnlockState()
    }

    func lock() {
        isUnlocked = false
        unlockExpirationDate = nil
    }

    func verify(pin: String) -> Bool {
        guard pin.count == 4, pin.allSatisfy(\.isNumber) else {
            return false
        }

        guard let savedPIN = readPIN() else {
            return false
        }

        let matches = savedPIN == pin
        if matches {
            unlock(until: Date().addingTimeInterval(unlockDuration))
        }

        return matches
    }

    func changePIN(to newPIN: String) -> Bool {
        guard newPIN.count == 4, newPIN.allSatisfy(\.isNumber) else {
            return false
        }

        do {
            try savePIN(newPIN)
            lock()
            return true
        } catch {
            return false
        }
    }

    func refreshUnlockState() {
        guard let unlockExpirationDate else {
            isUnlocked = false
            return
        }

        if Date() < unlockExpirationDate {
            isUnlocked = true
        } else {
            lock()
        }
    }

    func extendUnlockWindow() {
        guard isCurrentlyUnlocked else {
            lock()
            return
        }

        unlock(until: Date().addingTimeInterval(unlockDuration))
    }

    var isCurrentlyUnlocked: Bool {
        guard let unlockExpirationDate else { return false }
        return Date() < unlockExpirationDate
    }

    private func unlock(until expirationDate: Date) {
        unlockExpirationDate = expirationDate
        isUnlocked = true
    }

    private func seedDefaultPINIfNeeded() {
        guard readPIN() == nil else { return }

        do {
            try savePIN("6996")
        } catch {
            // Intentionally silent for now.
        }
    }

    private func savePIN(_ pin: String) throws {
        let data = Data(pin.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status: OSStatus
        if readPIN() != nil {
            status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        } else {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    private func readPIN() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let pin = String(data: data, encoding: .utf8) else {
            return nil
        }

        return pin
    }
}
