// RegisterView.swift
import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var isLoading = false

    var passwordsMatch: Bool { password == confirm }
    var isFormValid: Bool { !name.isEmpty && !email.isEmpty && password.count >= 6 && passwordsMatch }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#1a1a2e"), Color(hex: "#16213e")],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Create Account")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Start your focus journey today")
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)

                    VStack(spacing: 14) {
                        AuthTextField(placeholder: "Full Name", text: $name, icon: "person.fill", isSecure: false)
                        AuthTextField(placeholder: "Email", text: $email, icon: "envelope.fill", isSecure: false)
                            .keyboardType(.emailAddress).textInputAutocapitalization(.never)
                        AuthTextField(placeholder: "Password (min 6 chars)", text: $password, icon: "lock.fill", isSecure: true)
                        AuthTextField(placeholder: "Confirm Password", text: $confirm, icon: "lock.fill", isSecure: true)

                        if !confirm.isEmpty && !passwordsMatch {
                            Text("Passwords do not match").font(.caption).foregroundColor(.red)
                        }
                        if let error = authViewModel.errorMessage {
                            Text(error).font(.caption).foregroundColor(.red).multilineTextAlignment(.center)
                        }

                        Button {
                            Task {
                                isLoading = true
                                await authViewModel.signUp(email: email, password: password, name: name)
                                isLoading = false
                            }
                        } label: {
                            HStack {
                                if isLoading { ProgressView().tint(.white) }
                                else { Text("Create Account").font(.headline).foregroundColor(.white) }
                            }
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(isFormValid ?
                                LinearGradient(colors: [.orange, Color(hex: "#e05c00")],
                                    startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.5)],
                                    startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(16)
                        }
                        .disabled(!isFormValid || isLoading)
                    }
                    .padding(.horizontal, 24)

                    HStack {
                        Text("Already have an account?").foregroundColor(.gray)
                        Button("Sign In") { dismiss() }.foregroundColor(.orange).fontWeight(.semibold)
                    }
                    .font(.subheadline).padding(.bottom, 40)
                }
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").foregroundColor(.orange)
                }
            }
        }
    }
}
