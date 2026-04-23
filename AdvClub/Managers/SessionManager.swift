//
//  SessionManager.swift
//  AdvClub
//
//  Created by Chase Smith on 4/9/26.
//

import Foundation
import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

@MainActor
final class SessionManager: ObservableObject {
    @Published private(set) var currentUser: AppUser?
    @Published private(set) var users: [AppUser] = []
    @Published var loginErrorMessage: String?

    private let db = Firestore.firestore()
    private lazy var functions = Functions.functions()
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var currentUserListener: ListenerRegistration?
    private var usersListener: ListenerRegistration?

    init() {
        startAuthListener()
    }

    deinit {
        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }

        currentUserListener?.remove()
        usersListener?.remove()
    }

    var isAuthenticated: Bool {
        Auth.auth().currentUser != nil
    }

    var isSuperAdmin: Bool {
        currentUser?.role == .superAdmin
    }

    var isAdmin: Bool {
        currentUser?.role == .admin || currentUser?.role == .superAdmin
    }

    var isMember: Bool {
        currentUser?.role == .member
    }

    func login(email: String, password: String) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedEmail.isEmpty == false, normalizedPassword.isEmpty == false else {
            loginErrorMessage = "Enter your email and password."
            return
        }

        Auth.auth().signIn(withEmail: normalizedEmail, password: normalizedPassword) { [weak self] _, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    self.loginErrorMessage = error.localizedDescription
                    self.currentUser = nil
                    self.users = []
                    return
                }

                self.loginErrorMessage = nil
            }
        }
    }

    func logout() {
        currentUserListener?.remove()
        currentUserListener = nil
        usersListener?.remove()
        usersListener = nil

        do {
            try Auth.auth().signOut()
            currentUser = nil
            users = []
            loginErrorMessage = nil
        } catch {
            loginErrorMessage = error.localizedDescription
        }
    }

    func createMember(
        email: String,
        password: String,
        displayName: String,
        role: UserRole = .member
    ) async -> Result<AppUser, SessionError> {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedEmail.isEmpty == false else {
            return .failure(.missingEmail)
        }

        guard normalizedPassword.isEmpty == false else {
            return .failure(.missingPassword)
        }

        guard normalizedDisplayName.isEmpty == false else {
            return .failure(.missingDisplayName)
        }

        guard isAdmin else {
            return .failure(.notAuthorized)
        }

        if role == .admin || role == .superAdmin {
            guard isSuperAdmin else {
                return .failure(.notAuthorized)
            }
        }

        do {
            let callable = functions.httpsCallable("createUser")
            let result = try await callable.call([
                "email": normalizedEmail,
                "password": normalizedPassword,
                "displayName": normalizedDisplayName,
                "role": role.rawValue,
            ])

            guard let data = result.data as? [String: Any],
                  let uid = data["uid"] as? String,
                  let returnedEmail = data["email"] as? String,
                  let returnedDisplayName = data["displayName"] as? String,
                  let returnedRoleRaw = data["role"] as? String,
                  let returnedRole = decodeRole(returnedRoleRaw),
                  let isActive = data["isActive"] as? Bool else {
                return .failure(.backendNotConfigured)
            }

            let quarterlyAllowance = data["quarterlyAllowance"] as? Int ?? 30

            let user = AppUser(
                id: uid,
                email: returnedEmail,
                displayName: returnedDisplayName,
                role: returnedRole,
                isActive: isActive,
                quarterlyAllowance: quarterlyAllowance
            )

            return .success(user)
        } catch let error as NSError {
            await MainActor.run {
                self.loginErrorMessage = error.localizedDescription
            }

            if let code = FunctionsErrorCode(rawValue: error.code) {
                switch code {
                case .permissionDenied:
                    return .failure(.notAuthorized)
                case .unauthenticated:
                    return .failure(.notAuthorized)
                case .invalidArgument:
                    return .failure(.missingDisplayName)
                case .alreadyExists:
                    return .failure(.emailAlreadyExists)
                default:
                    return .failure(.backendNotConfigured)
                }
            }

            return .failure(.backendNotConfigured)
        }
    }

    func updateUser(
        userID: String,
        email: String,
        password: String,
        displayName: String,
        role: UserRole,
        isActive: Bool
    ) -> Result<AppUser, SessionError> {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedEmail.isEmpty == false else {
            return .failure(.missingEmail)
        }

        guard normalizedDisplayName.isEmpty == false else {
            return .failure(.missingDisplayName)
        }

        let existingUser = users.first(where: { $0.id == userID }) ?? currentUser
        guard let existingUser, existingUser.id == userID else {
            return .failure(.userNotFound)
        }

        guard canModifyUser(existingUser) else {
            return .failure(.notAuthorized)
        }

        if role == .superAdmin {
            guard isSuperAdmin else {
                return .failure(.notAuthorized)
            }
        }

        if isSuperAdmin == false && role == .admin {
            guard existingUser.role == .member else {
                return .failure(.notAuthorized)
            }
        }

        if normalizedEmail != existingUser.email {
            return .failure(.backendNotConfigured)
        }

        let updatedUser = AppUser(
            id: existingUser.id,
            email: existingUser.email,
            displayName: normalizedDisplayName,
            role: role,
            isActive: isActive,
            quarterlyAllowance: existingUser.quarterlyAllowance
        )

        Task {
            do {
                try await db.collection("users").document(userID).updateData([
                    "displayName": normalizedDisplayName,
                    "role": role.rawValue,
                    "isActive": isActive,
                    "updatedAt": FieldValue.serverTimestamp()
                ])

                if userID == Auth.auth().currentUser?.uid, normalizedPassword.isEmpty == false {
                    try await updateCurrentUserPassword(to: normalizedPassword)
                }
            } catch let error as SessionError {
                await MainActor.run {
                    self.loginErrorMessage = error.localizedDescription
                }
            } catch {
                await MainActor.run {
                    self.loginErrorMessage = error.localizedDescription
                }
            }
        }

        if currentUser?.id == userID {
            currentUser = updatedUser
        }

        if let index = users.firstIndex(where: { $0.id == userID }) {
            users[index] = updatedUser
        }

        return .success(updatedUser)
    }

    func allUsers() -> [AppUser] {
        users.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func setUserActiveState(userID: String, isActive: Bool) {
        guard isAdmin else {
            loginErrorMessage = SessionError.notAuthorized.localizedDescription
            return
        }

        guard let targetUser = users.first(where: { $0.id == userID }) ?? currentUser,
              canModifyUser(targetUser) else {
            loginErrorMessage = SessionError.notAuthorized.localizedDescription
            return
        }

        Task {
            do {
                try await db.collection("users").document(userID).updateData([
                    "isActive": isActive,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
            } catch {
                await MainActor.run {
                    self.loginErrorMessage = error.localizedDescription
                }
            }
        }
    }

    func deleteUser(userID: String) {
        guard isAdmin else {
            loginErrorMessage = SessionError.notAuthorized.localizedDescription
            return
        }

        guard let targetUser = users.first(where: { $0.id == userID }) ?? currentUser,
              canModifyUser(targetUser) else {
            loginErrorMessage = SessionError.notAuthorized.localizedDescription
            return
        }

        Task {
            do {
                try await db.collection("users").document(userID).delete()
            } catch {
                await MainActor.run {
                    self.loginErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func startAuthListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in
                guard let self else { return }
                self.handleAuthStateChanged(firebaseUser)
            }
        }
    }

    private func handleAuthStateChanged(_ firebaseUser: FirebaseAuth.User?) {
        currentUserListener?.remove()
        currentUserListener = nil
        usersListener?.remove()
        usersListener = nil

        guard let firebaseUser else {
            currentUser = nil
            users = []
            return
        }
        
        //Testing code needs to be removed
        print("Authenticated Firebase UID:", firebaseUser.uid)
        print("Authenticated Firebase email:", firebaseUser.email ?? "nil")

        listenToCurrentUser(uid: firebaseUser.uid)
    }

    private func listenToCurrentUser(uid: String) {
        currentUserListener = db.collection("users").document(uid).addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    self.loginErrorMessage = error.localizedDescription
                    self.currentUser = nil
                    self.users = []
                    return
                }
                
                //Test code needs to be removed
                print("Firestore snapshot exists:", snapshot?.exists ?? false)
                print("Firestore snapshot data:", snapshot?.data() ?? [:])

                guard let snapshot, snapshot.exists, let user = self.makeAppUser(from: snapshot) else {
                    self.loginErrorMessage = SessionError.profileMissing.localizedDescription
                    self.currentUser = nil
                    self.users = []
                    return
                }

                self.currentUser = user
                
                //Test code needs to be removed.
                print("Loaded currentUser:", user.email, user.role.rawValue, user.isActive)
                print("isAdmin evaluates to:", user.role == .admin)
                
                self.loginErrorMessage = nil

                if user.role == .admin || user.role == .superAdmin {
                    self.listenToUsersCollection()
                } else {
                    self.usersListener?.remove()
                    self.usersListener = nil
                    self.users = [user]
                }
            }
        }
    }

    private func listenToUsersCollection() {
        usersListener?.remove()
        usersListener = db.collection("users").addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    self.loginErrorMessage = error.localizedDescription
                    return
                }

                guard let snapshot else {
                    self.users = []
                    return
                }

                self.users = snapshot.documents.compactMap { self.makeAppUser(from: $0) }
                    .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            }
        }
    }

    private func makeAppUser(from snapshot: DocumentSnapshot) -> AppUser? {
        guard let data = snapshot.data() else {
            return nil
        }
        
        //Test code needs to be removed
        print("Decoded Firestore raw data:", data)
        print("Role raw value:", data["role"] ?? "missing-role")

        guard let email = data["email"] as? String,
              let displayName = data["displayName"] as? String,
              let roleRawValue = data["role"] as? String,
              let role = decodeRole(roleRawValue),
              let isActive = data["isActive"] as? Bool else {
            return nil
        }

        let quarterlyAllowance = data["quarterlyAllowance"] as? Int ?? 30

        //Test code needs to be removed
        print("Creating AppUser with role:", role.rawValue)
        
        return AppUser(
            id: snapshot.documentID,
            email: email,
            displayName: displayName,
            role: role,
            isActive: isActive,
            quarterlyAllowance: quarterlyAllowance
        )
    }

    private func canModifyUser(_ targetUser: AppUser) -> Bool {
        guard let currentUser else { return false }

        if currentUser.role == .superAdmin {
            return true
        }

        if currentUser.role == .admin {
            return targetUser.role == .member
        }

        return currentUser.id == targetUser.id
    }

    private func decodeRole(_ rawValue: String) -> UserRole? {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "member":
            return .member
        case "admin":
            return .admin
        case "superadmin", "super_admin", "super admin":
            return .superAdmin
        default:
            return nil
        }
    }

    private func updateCurrentUserPassword(to newPassword: String) async throws {
        guard newPassword.isEmpty == false else {
            throw SessionError.missingPassword
        }

        guard let authUser = Auth.auth().currentUser else {
            throw SessionError.userNotFound
        }

        do {
            try await authUser.updatePassword(to: newPassword)
        } catch let error as NSError {
            if error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                throw SessionError.requiresReauthentication
            }
            throw error
        }
    }
}

enum SessionError: LocalizedError {
    case missingEmail
    case missingPassword
    case missingDisplayName
    case emailAlreadyExists
    case userNotFound
    case duplicateEmail
    case notAuthorized
    case profileMissing
    case backendNotConfigured
    case requiresReauthentication

    var errorDescription: String? {
        switch self {
        case .missingEmail:
            return "Email is required."
        case .missingPassword:
            return "Password is required."
        case .missingDisplayName:
            return "Display name is required."
        case .emailAlreadyExists:
            return "A user with that email already exists."
        case .userNotFound:
            return "The selected user could not be found."
        case .duplicateEmail:
            return "Another user already uses that email."
        case .notAuthorized:
            return "You are not authorized to perform this action."
        case .profileMissing:
            return "Your user profile could not be found in Firestore."
        case .backendNotConfigured:
            return "This action requires a secure backend or Cloud Function before it can be enabled in Firebase."
        case .requiresReauthentication:
            return "Please sign in again before updating your password."
        }
    }
}
