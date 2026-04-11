// AuthService.swift
import Foundation
import FirebaseAuth
import Combine

class AuthService: ObservableObject {
    static let shared = AuthService()
    @Published var currentUser: User? = Auth.auth().currentUser
    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async { self?.currentUser = user }
        }
    }

    deinit {
        if let h = handle { Auth.auth().removeStateDidChangeListener(h) }
    }

    var uid: String? { currentUser?.uid }

    // MARK: - Sign Up
    func signUp(email: String, password: String, displayName: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        try await changeRequest.commitChanges()
        // Create default settings in Firestore
        try await FirebaseService.shared.saveSettings(UserSettings(), uid: result.user.uid)
    }

    // MARK: - Sign In
    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    // MARK: - Sign Out
    func signOut() throws {
        try Auth.auth().signOut()
        DispatchQueue.main.async {
            self.currentUser = nil
        }
    }

    // MARK: - Reset Password
    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    // MARK: - Delete Account
    func deleteAccount() async throws {
        guard let user = currentUser else { return }
        // Delete all user data from Firestore first
        if let uid = self.uid {
            try await FirebaseService.shared.deleteAllUserData(uid: uid)
        }
        try await user.delete()
    }
}
