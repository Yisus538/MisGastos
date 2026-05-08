// =============================================================================
// ForgotPasswordView.swift — Pantalla de recuperación de contraseña
// =============================================================================
// Rol en la app:
//   Permite al usuario recuperar el acceso a su cuenta si olvidó su contraseña.
//   Envía un email con instrucciones de recuperación usando `supabase.auth.resetPasswordForEmail`.
//   La vista tiene dos estados:
//   1. **Formulario**: campo de email + botón de envío.
//   2. **Confirmación**: mensaje de éxito con el email al que se enviaron las instrucciones.
//
// Equivalente Android:
//   `FirebaseAuth.sendPasswordResetEmail(email)` + Activity/Fragment de confirmación.
//   En Compose: un `@Composable fun ForgotPasswordScreen()` con state management
//   para alternar entre el formulario y la pantalla de éxito.
//
// Seguridad (privacy by design):
//   La función `enviar()` siempre muestra el estado de éxito, independientemente de
//   si el email existe en la base de datos. Esto previene la enumeración de usuarios
//   (user enumeration attack): un atacante no puede saber si un email está registrado.
//   Supabase aplica la misma estrategia internamente.
//
// Animación de transición:
//   `.transition(.opacity.combined(with: .move(edge: .trailing)))` anima el cambio
//   de formulario a confirmación con un fade + deslizamiento desde la derecha.
//   Requiere que el cambio esté dentro de `withAnimation { }` para activarse.
//   Equivalente Android: `AnimatedContent` en Compose o `ViewPager` con animación.
//
// `defer` para cleanup de estado de carga:
//   `defer { isLoading = false }` garantiza que `isLoading` vuelve a `false`
//   cuando `enviar()` retorna, incluso si ocurre un error. Sin `defer`, si
//   `resetPassword` lanzara una excepción no capturada, el botón quedaría en
//   estado "cargando" indefinidamente.
// =============================================================================

import SwiftUI

/// Vista de recuperación de contraseña con dos estados: formulario y confirmación.
///
/// Equivalente Android: `ForgotPasswordActivity` con `FirebaseAuth.sendPasswordResetEmail()`.
struct ForgotPasswordView: View {

    // MARK: - Estado

    /// Dismisses la sheet de vuelta a `LoginView`.
    @Environment(\.dismiss) private var dismiss

    /// Email ingresado por el usuario.
    @State private var email = ""

    /// `true` mientras el request a Supabase está en curso.
    @State private var isLoading = false

    /// `true` después de enviar el email — alterna la vista de formulario a confirmación.
    @State private var enviado = false

    // MARK: - Validación

    /// Validación básica del formato de email.
    ///
    /// Una validación más robusta usaría regex para verificar el formato RFC 5322.
    /// Para el TP, verificar que tiene `@` y `.` es suficiente para habilitar el botón.
    private var isValidEmail: Bool {
        email.contains("@") && email.contains(".")
    }

    // MARK: - Vista principal

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Botón de volver
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

                // Alternar entre formulario y confirmación según el estado `enviado`
                if enviado {
                    successView
                } else {
                    formView
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Vista de formulario

    /// Formulario para ingresar el email y solicitar el reset.
    private var formView: some View {
        VStack(alignment: .center, spacing: 0) {
            // Ícono decorativo
            ZStack {
                Circle().fill(Color.saGreenBg).frame(width: 80, height: 80)
                Image(systemName: "key.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.saGreen)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)

            // Título y descripción
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

            // Campo de email
            SAField(placeholder: "tucorreo@ejemplo.com", text: $email, icon: "envelope")
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            // Botón de envío — deshabilitado y semitransparente si el email no es válido
            SAButton(title: "Enviar instrucciones", isLoading: isLoading) {
                Task { await enviar() }
            }
            .disabled(!isValidEmail)
            .opacity(isValidEmail ? 1 : 0.5)
            .padding(.top, 16)

            // Link de volver al login
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

    // MARK: - Vista de confirmación

    /// Pantalla de éxito mostrada después de enviar el email de recuperación.
    ///
    /// Informa al usuario que el email fue enviado, sin revelar si existía en la DB.
    /// El botón "No recibí el correo" permite volver al formulario para reintentar.
    private var successView: some View {
        VStack(alignment: .center, spacing: 0) {
            // Ícono de email enviado
            ZStack {
                Circle().fill(Color.saGreenBg).frame(width: 96, height: 96)
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.saGreen)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 28)

            // Título
            Text("Revisá tu bandeja")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.saLabel)
                .tracking(-0.8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            // Mensaje con el email al que se enviaron las instrucciones
            Text("Enviamos las instrucciones a:")
                .font(.system(size: 15))
                .foregroundStyle(Color.saLabel3)
                .padding(.top, 10)
                .frame(maxWidth: .infinity, alignment: .center)

            // Email resaltado en verde
            Text(email)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.saGreen)
                .padding(.top, 4)
                .padding(.bottom, 36)
                .frame(maxWidth: .infinity, alignment: .center)

            // Botón principal: volver al login
            SAButton(title: "Volver al inicio de sesión") {
                dismiss()
            }

            // Opción de reintento: vuelve al formulario
            Button(action: { enviado = false }) {
                Text("No recibí el correo")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.saLabel3)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
            }
        }
        // Transición animada desde el formulario: fade + deslizamiento desde la derecha
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    // MARK: - Lógica de envío

    /// Envía el email de recuperación a Supabase y muestra el estado de éxito.
    ///
    /// La respuesta de Supabase siempre se ignora (success o error):
    /// para no revelar si el email existe, siempre se muestra la pantalla de confirmación.
    ///
    /// `defer { isLoading = false }` garantiza que el spinner desaparece al terminar
    /// la función, sea por éxito o error. Equivalente Android: `try/finally` en Kotlin.
    private func enviar() async {
        isLoading = true
        defer { isLoading = false }   // Siempre se ejecuta al salir de la función

        // Normalizar el email antes de enviarlo (trim + lowercase)
        let emailNorm = email.lowercased().trimmingCharacters(in: .whitespaces)

        // Enviar request a Supabase — resultado ignorado intencionalmente (privacidad)
        try? await SupabaseService.shared.resetPassword(email: emailNorm)

        // Animar la transición al estado de confirmación
        withAnimation(.easeInOut(duration: 0.3)) {
            enviado = true
        }
    }
}
