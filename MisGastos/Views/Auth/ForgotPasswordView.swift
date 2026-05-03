import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var isLoading = false
    @State private var enviado = false

    private var isValidEmail: Bool {
        email.contains("@") && email.contains(".")
    }

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.saLabel)
                        .frame(width: 36, height: 36)
                        .background(Color.saBg)
                        .clipShape(Circle())
                }
                .padding(.top, 56)
                .padding(.bottom, 24)

                if enviado {
                    successView
                } else {
                    formView
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Form

    private var formView: some View {
        VStack(alignment: .center, spacing: 0) {
            ZStack {
                Circle().fill(Color.saGreenBg).frame(width: 80, height: 80)
                Image(systemName: "key.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.saGreen)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)

            Text("¿Olvidaste tu contraseña?")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.saLabel)
                .tracking(-0.8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Text("Ingresá tu correo y te enviamos instrucciones para recuperar tu cuenta.")
                .font(.system(size: 15))
                .foregroundStyle(Color.saLabel3)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)

            SAField(placeholder: "tucorreo@ejemplo.com", text: $email, icon: "envelope")
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            SAButton(title: "Enviar instrucciones", isLoading: isLoading) {
                Task { await enviar() }
            }
            .disabled(!isValidEmail)
            .opacity(isValidEmail ? 1 : 0.5)
            .padding(.top, 16)

            HStack(spacing: 4) {
                Text("Recordé mi contraseña.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.saLabel3)
                Button("Iniciar sesión") { dismiss() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.saGreen)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 22)
        }
    }

    // MARK: - Success

    private var successView: some View {
        VStack(alignment: .center, spacing: 0) {
            ZStack {
                Circle().fill(Color.saGreenBg).frame(width: 96, height: 96)
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.saGreen)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 28)

            Text("Revisá tu bandeja")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.saLabel)
                .tracking(-0.8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Text("Enviamos las instrucciones a:")
                .font(.system(size: 15))
                .foregroundStyle(Color.saLabel3)
                .padding(.top, 10)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(email)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.saGreen)
                .padding(.top, 4)
                .padding(.bottom, 36)
                .frame(maxWidth: .infinity, alignment: .center)

            SAButton(title: "Volver al inicio de sesión") {
                dismiss()
            }

            Button(action: { enviado = false }) {
                Text("No recibí el correo")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.saLabel3)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    // MARK: - Logic

    private func enviar() async {
        isLoading = true
        defer { isLoading = false }
        let emailNorm = email.lowercased().trimmingCharacters(in: .whitespaces)
        // Siempre mostramos "enviado" para no revelar si el email existe
        try? await SupabaseService.shared.resetPassword(email: emailNorm)
        withAnimation(.easeInOut(duration: 0.3)) {
            enviado = true
        }
    }
}
