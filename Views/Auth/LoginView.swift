// LoginView.swift
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showRegister = false
    @State private var showForgot = false
    @FocusState private var focusField: Field?

    enum Field { case email, password }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(colors: [Color(hex: "#1a1a2e"), Color(hex: "#16213e"), Color(hex: "#0f3460")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {

                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "timer")
                                .font(.system(size: 70))
                                .foregroundStyle(LinearGradient(colors: [.orange, .red],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                .shadow(color: .orange.opacity(0.5), radius: 20)
                            Text("FocusFlow")
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("Stay focused. Get things done.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.top, 60)

                        // Form
                        VStack(spacing: 16) {
                            AuthTextField(placeholder: "Email", text: $email,
                                         icon: "envelope.fill", isSecure: false)
                                .focused($focusField, equals: .email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                            AuthTextField(placeholder: "Password", text: $password,
                                         icon: "lock.fill", isSecure: true)
                                .focused($focusField, equals: .password)

                            if let error = authViewModel.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red.opacity(0.9))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }

                            // Sign In Button
                            Button {
                                Task {
                                    isLoading = true
                                    await authViewModel.signIn(email: email, password: password)
                                    isLoading = false
                                }
                            } label: {
                                HStack {
                                    if isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Sign In")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(LinearGradient(colors: [.orange, Color(hex: "#e05c00")],
                                    startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(16)
                                .shadow(color: .orange.opacity(0.4), radius: 12)
                            }
                            .disabled(email.isEmpty || password.isEmpty || isLoading)

                            Button("Forgot Password?") { showForgot = true }
                                .font(.footnote)
                                .foregroundColor(.orange.opacity(0.8))
                        }
                        .padding(.horizontal, 24)

                        // Register
                        HStack {
                            Text("Don't have an account?").foregroundColor(.white.opacity(0.6))
                            Button("Sign Up") { showRegister = true }
                                .foregroundColor(.orange)
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationDestination(isPresented: $showRegister) { RegisterView() }
            .sheet(isPresented: $showForgot) { ForgotPasswordView() }
        }
    }
}

// MARK: - Auth Text Field
struct AuthTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    let isSecure: Bool
    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.orange.opacity(0.8))
                .frame(width: 20)
            if isSecure && !isRevealed {
                SecureField(placeholder, text: $text)
                    .foregroundColor(.white)
            } else {
                TextField(placeholder, text: $text)
                    .foregroundColor(.white)
            }
            if isSecure {
                Button { isRevealed.toggle() } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Color.white.opacity(0.08))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - Forgot Password
struct ForgotPasswordView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#1a1a2e").ignoresSafeArea()
                VStack(spacing: 24) {
                    Text("Reset your password")
                        .font(.title2).bold().foregroundColor(.white)
                    Text("Enter your email and we'll send you a link to reset your password.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                    AuthTextField(placeholder: "Email", text: $email, icon: "envelope.fill", isSecure: false)
                    if let msg = authViewModel.errorMessage {
                        Text(msg).foregroundColor(msg.contains("sent") ? .green : .red).font(.caption)
                    }
                    Button("Send Reset Link") {
                        Task { await authViewModel.resetPassword(email: email) }
                    }
                    .disabled(email.isEmpty)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Color.orange).cornerRadius(14)
                    .foregroundColor(.white).fontWeight(.semibold)
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
    }
}
