import SwiftUI

struct LoginView: View {
    @State private var viewModel = AuthViewModel()
    @State private var showRegister = false
    @State private var showForgot = false
    @AppStorage("isLoggedIn")   private var isLoggedIn: Bool = false
    @AppStorage("usuarioEmail") private var usuarioEmail: String = ""

    private let biometric = BiometricService.shared

    private var showBiometric: Bool {
        biometric.isAvailable && !usuarioEmail.isEmpty
    }

    private var biometricIcon: String {
        biometric.biometricType == .faceID ? "faceid" : "touchid"
    }

    private var biometricLabel: String {
        biometric.biometricType == .faceID ? "Continuar con Face ID" : "Continuar con Touch ID"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.saBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Brand
                            SABrandMark(size: 64)
                                .padding(.top, 60)
                                .padding(.bottom, 24)

                            Text("Bienvenido")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(Color.saLabel)
                                .tracking(-1)
                            Text("Iniciá sesión para seguir ahorrando")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.saLabel3)
                                .padding(.top, 8)
                                .padding(.bottom, 32)

                            // Fields
                            VStack(spacing: 12) {
                                SAField(placeholder: "Correo electrónico", text: $viewModel.email, icon: "envelope")
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                SAField(placeholder: "Contraseña", text: $viewModel.password, icon: "lock", isSecure: true)
                            }

                            // Forgot password
                            HStack {
                                Spacer()
                                Button("¿Olvidaste tu contraseña?") { showForgot = true }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.saGreen)
                            }
                            .padding(.top, 14)
                            .padding(.bottom, 28)

                            if let error = viewModel.errorMessage {
                                Text(error).font(.caption).foregroundStyle(Color.saDanger)
                                    .padding(.bottom, 8)
                            }

                            SAButton(title: "Iniciar sesión", isLoading: viewModel.isLoading) {
                                Task { await viewModel.login() }
                            }

                            // Divider
                            HStack(spacing: 12) {
                                Rectangle().fill(Color.saSep).frame(height: 0.5)
                                Text("o continuá con")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.saLabel3)
                                Rectangle().fill(Color.saSep).frame(height: 0.5)
                            }
                            .padding(.vertical, 26)

                            // Social buttons side by side
                            HStack(spacing: 12) {
                                socialBtn(icon: "apple.logo", label: "Apple")
                                socialBtn(icon: "globe", label: "Google")
                            }

                            // Biometric login (only when available + user logged in before)
                            if showBiometric {
                                Button {
                                    Task {
                                        let ok = await biometric.authenticate(reason: "Accedé a Súper Ahorro")
                                        if ok { isLoggedIn = true }
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: biometricIcon)
                                            .font(.system(size: 20))
                                        Text(biometricLabel)
                                            .font(.system(size: 15, weight: .semibold))
                                    }
                                    .foregroundStyle(Color.saGreen)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.saGreenBg)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 12)
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    // Register link
                    HStack(spacing: 4) {
                        Text("¿No tenés cuenta?")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.saLabel3)
                        Button("Registrate") { showRegister = true }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.saGreen)
                    }
                    .padding(.vertical, 24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .sheet(isPresented: $showRegister) { RegisterView() }
            .sheet(isPresented: $showForgot) { ForgotPasswordView() }
        }
    }

    @ViewBuilder
    private func socialBtn(icon: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(Color.saLabel)
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.saLabel)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Color.saCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.saSep, lineWidth: 0.5)
        )
    }
}
