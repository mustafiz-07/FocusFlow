// AuthViewModel.swift
import Foundation
import FirebaseAuth
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var currentUser: User? = nil
    @Published var isLoading = true
    @Published var errorMessage: String? = nil

    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        authService.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.currentUser = user
                self?.isLoading = false
            }
            .store(in: &cancellables)
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        do { try await authService.signIn(email: email, password: password) }
        catch { errorMessage = friendlyError(error) }
    }

    func signUp(email: String, password: String, name: String) async {
        errorMessage = nil
        do { try await authService.signUp(email: email, password: password, displayName: name) }
        catch { errorMessage = friendlyError(error) }
    }

    func signOut() {
        errorMessage = nil

        do {
            try authService.signOut()
            currentUser = nil
        } catch {
            errorMessage = friendlyError(error)
        }
    }

    func resetPassword(email: String) async {
        errorMessage = nil
        do {
            try await authService.resetPassword(email: email)
            errorMessage = "Password reset email sent!"
        }
        catch { errorMessage = friendlyError(error) }
    }

    private func friendlyError(_ error: Error) -> String {
        guard let code = AuthErrorCode(_bridgedNSError: error as NSError) else {
            return error.localizedDescription
        }

        switch code.code {
        case .emailAlreadyInUse: return "This email is already registered."
        case .invalidEmail: return "Please enter a valid email address."
        case .weakPassword: return "Password must be at least 6 characters."
        case .wrongPassword, .invalidCredential: return "Incorrect email or password."
        case .userNotFound: return "No account found with this email."
        case .networkError: return "Network error. Please check your connection."
        default: return error.localizedDescription
        }
    }
}
