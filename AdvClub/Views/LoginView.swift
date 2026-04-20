//
//  LoginView.swift
//  AdvClub
//
//  Created by Chase Smith on 4/9/26.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var sessionManager: SessionManager

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            Color.appBackgroundColor
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Image("AdvClub")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Text("Adventure Club")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Member Login")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.72))
                }

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))

                        TextField("Enter your email", text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))

                        SecureField("Enter your password", text: $password)
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.white)
                    }

                    if let errorMessage = sessionManager.loginErrorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        sessionManager.login(email: email, password: password)
                    } label: {
                        Text("Log In")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    VStack(spacing: 4) {
//                        Text("Temporary Admin Login")
//                            .font(.caption)
//                            .foregroundStyle(.white.opacity(0.75))
//
//                        Text("admin@advclub.local / Admin123!")
//                            .font(.caption2)
//                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.top, 4)
                }
                .padding(22)
                .background(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .frame(maxWidth: 420)

                Spacer()
            }
            .padding(24)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(SessionManager())
}
