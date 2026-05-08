// =============================================================================
// RegisterView.swift — Pantalla de registro de nueva cuenta
// =============================================================================
// Rol en la app:
//   Formulario de registro con nombre, email y contraseña. Incluye un indicador
//   visual de fortaleza de contraseña y un checkbox de términos y condiciones.
//   Delega el registro a `AuthViewModel` → `SupabaseService.register()`.
//
//   Supabase crea el usuario en su tabla `auth.users` con bcrypt + JWT.
//   No se guarda ninguna contraseña en SwiftData local.
//
// Equivalente Android:
//   `RegisterActivity` / `RegisterFragment` con:
//   - `TextInputLayout` con validación en tiempo real.
//   - Indicador de fortaleza de contraseña personalizado.
//   - `FirebaseAuth.createUserWithEmailAndPassword()` para el registro.
//   - O en Compose: `@Composable fun RegisterScreen(viewModel: AuthViewModel)`.
//
// Indicador de fortaleza de contraseña:
//   Se basa únicamente en la longitud (simplificación para el TP).
//   Una implementación robusta verificaría también:
//   - Mayúsculas y minúsculas mezcladas.
//   - Números y caracteres especiales.
//   - Contraseñas comunes (diccionario).
//
// Animación de barras:
//   `.animation(.easeInOut(duration: 0.2), value: strengthLevel)` hace que
//   las barras de fortaleza se animen suavemente al cambiar. SwiftUI detecta
//   el cambio en `strengthLevel` y anima la propiedad `fill` automáticamente.
//   Equivalente Android: `ValueAnimator` o `animateColorAsState` en Compose.
// =============================================================================

import SwiftUI

/// Pantalla de registro de nueva cuenta de Súper Ahorro.
///
/// Flujo de registro:
/// 1. Usuario completa nombre + email + contraseña.
/// 2. Acepta términos y condiciones (requerido para habilitar el botón).
/// 3. Toca "Crear cuenta" → `viewModel.register()`.
/// 4. Supabase crea el usuario → JWT guardado en Keychain → `SessionStore` navega a `MainTabView`.
///
/// Equivalente Android: `RegisterFragment` con `FirebaseAuth.createUserWithEmailAndPassword()`.
struct RegisterView: View {

    // MARK: - ViewModel

    /// ViewModel compartido con `LoginView` — maneja el estado de registro.
    @State private var viewModel = AuthViewModel()

    /// Dismisses esta sheet de vuelta a `LoginView`.
    @Environment(\.dismiss) private var dismiss

    // MARK: - Estado de UI

    /// Si el usuario aceptó los términos — el botón de registro está deshabilitado si es `false`.
    @State private var termsAccepted = true

    // MARK: - Indicador de fortaleza de contraseña

    /// Nivel de fortaleza de la contraseña basado en la longitud (0-4).
    ///
    /// 0: vacía / 1: débil (<6) / 2: regular (<10) / 3: buena (<14) / 4: segura (14+)
    private var strengthLevel: Int {
        let n = viewModel.password.count
        if n == 0 { return 0 }
        if n < 6  { return 1 }
        if n < 10 { return 2 }
        if n < 14 { return 3 }
        return 4
    }

    // MARK: - Vista principal

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Botón de volver (dismiss la sheet)
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

                    // Encabezado
                    Text("Creá tu cuenta")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.saLabel)
                        .tracking(-1)
                    Text("Empezá a ahorrar en segundos")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.saLabel3)
                        .padding(.top, 6)
                        .padding(.bottom, 28)

                    // Campos del formulario
                    VStack(spacing: 12) {
                        // Nombre completo — se guarda en user_metadata de Supabase Auth
                        SAField(placeholder: "Nombre completo", text: $viewModel.nombre, icon: "person")

                        // Email — usado como identificador único del usuario en Supabase
                        SAField(placeholder: "Correo electrónico", text: $viewModel.email, icon: "envelope")
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)

                        // Contraseña — mínimo 6 caracteres (limitación de Supabase Auth por defecto)
                        SAField(placeholder: "Creá una contraseña", text: $viewModel.password, icon: "lock", isSecure: true)
                    }

                    // Indicador de fortaleza de contraseña: 4 barras animadas
                    // Barras llenas (verde) = fortaleza actual; vacías (separador) = nivel no alcanzado
                    HStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(i < strengthLevel ? Color.saGreen : Color.saSep)
                                .frame(height: 3)
                                // Animar el cambio de color cuando strengthLevel cambia
                                .animation(.easeInOut(duration: 0.2), value: strengthLevel)
                        }
                    }
                    .padding(.top, 14)
                    .padding(.horizontal, 2)

                    // Etiqueta textual de fortaleza
                    Text(strengthLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.saLabel3)
                        .padding(.top, 6)
                        .padding(.horizontal, 2)

                    // Checkbox de términos y condiciones
                    HStack(alignment: .top, spacing: 10) {
                        // Checkbox personalizado con checkmark animado
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(termsAccepted ? Color.saGreen : Color.saCard)
                                .frame(width: 22, height: 22)
                            if !termsAccepted {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.saLabel4, lineWidth: 1.5)
                                    .frame(width: 22, height: 22)
                            }
                            if termsAccepted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .onTapGesture { termsAccepted.toggle() }
                        .padding(.top, 1)

                        // Texto de términos con partes coloreadas
                        Text("Acepto los ") +
                        Text("Términos").foregroundColor(Color.saGreen) +
                        Text(" y la ") +
                        Text("Política de Privacidad").foregroundColor(Color.saGreen)
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(Color.saLabel3)
                    .padding(.top, 20)
                    .padding(.horizontal, 2)

                    // Mensajes de éxito o error
                    if let success = viewModel.successMessage {
                        // Registro exitoso (puede requerir verificación de email según config de Supabase)
                        Label(success, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.saGreen)
                            .padding(.top, 8)
                    } else if let error = viewModel.errorMessage {
                        Text(error).font(.caption).foregroundStyle(Color.saDanger).padding(.top, 8)
                    }

                    // Botón de crear cuenta — deshabilitado si no aceptó términos o ya se registró
                    SAButton(title: "Crear cuenta", isLoading: viewModel.isLoading) {
                        Task { await viewModel.register() }
                    }
                    .disabled(!termsAccepted || viewModel.successMessage != nil)
                    .padding(.top, 16)

                    // Link de volver al login
                    HStack(spacing: 4) {
                        Text("¿Ya tenés cuenta?")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.saLabel3)
                        Button("Iniciá sesión") { dismiss() }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.saGreen)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 22)
                    .padding(.bottom, 38)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Etiqueta de fortaleza

    /// Texto descriptivo del nivel de fortaleza de la contraseña.
    ///
    /// Se actualiza reactivamente cada vez que cambia `strengthLevel`.
    private var strengthLabel: String {
        switch strengthLevel {
        case 0: return "Ingresá una contraseña"
        case 1: return "Contraseña débil"
        case 2: return "Contraseña regular"
        case 3: return "Contraseña buena"
        default: return "Contraseña segura"
        }
    }
}
