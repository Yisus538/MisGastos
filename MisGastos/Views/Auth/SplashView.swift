// =============================================================================
// SplashView.swift — Pantalla de carga y punto de entrada de navegación
// =============================================================================
// Rol en la app:
//   Es la primera vista que el usuario ve al abrir la app. Muestra una animación
//   de carga (logo + nombre + puntos pulsantes) mientras:
//   1. Restaura la sesión de Supabase desde el Keychain (JWT).
//   2. Sincroniza preferencias de apariencia, membresía y compras pendientes.
//   3. Determina a qué pantalla navegar (MainTabView o LoginView).
//
//   Después de 2.2 segundos, navega a `MainTabView` o `LoginView` dependiendo
//   del estado de autenticación en `SessionStore.shared`.
//
// Equivalente Android:
//   `SplashScreen API` (Android 12+) + `SplashActivity` para versiones anteriores.
//   El routing post-splash se hace en `MainActivity.onCreate()` chequeando si el
//   usuario tiene sesión activa (SharedPreferences / DataStore / Room).
//   En Compose: `NavHost` con pantalla inicial condicional según el estado de auth.
//
// Animaciones en SwiftUI:
//   SwiftUI usa `withAnimation { }` para animar cambios de estado de forma implícita.
//   `.spring(response:dampingFraction:)` es una animación spring (resorte):
//   - `response`: qué tan rápido llega al valor destino (en segundos).
//   - `dampingFraction`: qué tan rápido se atenúa la oscilación (1.0 = sin rebote).
//   Equivalente Android: `ObjectAnimator`, `ValueAnimator` o `spring()` en Compose.
//
// Keychain y restauración de sesión:
//   El SDK de Supabase guarda el JWT (token de autenticación) en el Keychain de iOS.
//   Al abrir la app, `restaurarSesion()` recupera ese token para que el usuario
//   no tenga que iniciar sesión nuevamente. El Keychain sobrevive incluso si el
//   usuario borra y reinstala la app (en la misma cuenta de Apple).
//   Equivalente Android: el SDK de Firebase Auth usa SharedPreferences encriptado
//   o DataStore para persistir el token.
// =============================================================================

import SwiftUI
import SwiftData

/// Vista de splash que muestra la animación de carga y rutea a la pantalla correcta.
///
/// Controla el flujo de inicio de la app:
/// - Animaciones visuales durante 2.2 segundos.
/// - Operaciones asíncronas en background (restaurar sesión, sincronizar datos).
/// - Navegación a `MainTabView` o `LoginView` basada en `SessionStore`.
///
/// Equivalente Android: `SplashActivity` que verifica el token de auth y
/// lanza `MainActivity` o `LoginActivity` según corresponda.
struct SplashView: View {

    // MARK: - Preferencias de usuario

    /// Preferencia de apariencia (claro/oscuro/sistema) persistida en UserDefaults.
    /// `@AppStorage` equivale a `SharedPreferences` en Android — persiste entre sesiones.
    @AppStorage("aparienciaMode") private var aparienciaRaw: String = "sistema"

    // MARK: - Contexto de SwiftData

    /// Contexto de SwiftData inyectado por el environment — se usa para sincronizar
    /// compras pendientes y hacer pull de datos desde Supabase.
    /// Equivalente Android: `AppDatabase.getInstance(context)` obtenido con DI.
    @Environment(\.modelContext) private var modelContext

    // MARK: - Estado de navegación

    /// `true` cuando las animaciones terminan y la app navega a la pantalla principal.
    @State private var showMain = false

    // MARK: - SessionStore

    /// Singleton que suscribe al estado de autenticación de Supabase.
    /// Es la fuente de verdad de si el usuario está logueado o no.
    private let session = SessionStore.shared

    // MARK: - Esquema de color preferido

    /// Convierte el valor de `aparienciaRaw` al `ColorScheme` de SwiftUI.
    ///
    /// - `.claro` → `.light`
    /// - `.oscuro` → `.dark`
    /// - `.sistema` → `nil` (sigue la configuración del sistema)
    private var preferredScheme: ColorScheme? {
        (AparienciaMode(rawValue: aparienciaRaw) ?? .sistema).colorScheme
    }

    // MARK: - Estado de animaciones

    /// Escala inicial del logo (0.6 → 1.0 con efecto spring).
    @State private var logoScale: CGFloat = 0.6

    /// Opacidad del logo (0 → 1 con efecto spring).
    @State private var logoOpacity: Double = 0

    /// Opacidad del texto de nombre y eslogan.
    @State private var textOpacity: Double = 0

    /// Desplazamiento vertical del texto (8pt → 0 para efecto de aparición suave).
    @State private var textOffset: CGFloat = 8

    /// Controla la animación de los puntos pulsantes del indicador de carga.
    @State private var dotAnimating = false

    // MARK: - Vista

    var body: some View {
        if showMain {
            // Cuando las animaciones terminan, mostrar la pantalla correspondiente
            Group {
                // `SessionStore` suscribe a `authStateChanges` de Supabase —
                // `isAuthenticated` es verdad solo si hay una sesión JWT válida.
                if session.isAuthenticated { MainTabView() } else { LoginView() }
            }
            // Aplicar el esquema de color guardado en las preferencias del usuario
            .preferredColorScheme(preferredScheme)
        } else {
            // Pantalla de splash con animaciones
            ZStack {
                // Fondo con gradiente verde de la marca
                LinearGradient.saGreen.ignoresSafeArea()

                // Contenido central: logo + nombre + eslogan
                VStack(spacing: 24) {
                    // Logo de la app con animación spring (rebote suave al aparecer)
                    SABrandMark(size: 112)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)

                    // Nombre de la app y eslogan
                    VStack(spacing: 6) {
                        Text("Súper Ahorro")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.white)
                            .tracking(-1.4)   // Espaciado de letras ligeramente reducido (display text)
                        Text("Tus gastos del súper, bajo control")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .opacity(textOpacity)
                    .offset(y: textOffset)   // Aparece desde abajo con fade in
                }

                // Indicador de carga: tres puntos pulsantes en la parte inferior
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        // Tres puntos con delay escalonado para efecto de ola
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(Color.white)
                                .frame(width: 7, height: 7)
                                .opacity(dotAnimating ? 1.0 : 0.3)
                                .animation(
                                    .easeInOut(duration: 0.5)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(i) * 0.16),   // Delay escalonado por índice
                                    value: dotAnimating
                                )
                        }
                    }
                    .padding(.bottom, 64)
                }
            }
            .preferredColorScheme(.dark)   // El splash siempre en modo oscuro (fondo verde)
            .onAppear {
                // Animación 1: logo aparece con spring (rebote suave)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    logoScale = 1.0
                    logoOpacity = 1.0
                }
                // Animación 2: texto sube y aparece con fade, con 0.3s de delay
                withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                    textOpacity = 1.0
                    textOffset = 0
                }
                // Iniciar animación de puntos pulsantes
                dotAnimating = true

                // Operaciones asíncronas de inicialización en background
                Task {
                    // Actualizar tasas de cambio en segundo plano (sin bloquear la UI)
                    UserScopedStorage.shared.refreshExchangeRates()

                    // Restaurar sesión de Supabase desde el Keychain (JWT persistido)
                    // Esto evita que el usuario tenga que iniciar sesión en cada apertura
                    await SupabaseService.shared.restaurarSesion()

                    // Sincronizar preferencia de apariencia desde Supabase
                    // (para que sea consistente entre dispositivos)
                    if let remote = try? await SupabaseService.shared.fetchApariencia(),
                       AparienciaMode(rawValue: remote) != nil {
                        aparienciaRaw = remote
                    }

                    // Sincronizar membresía (plan Gratis/Pro) desde la nube
                    await MembresiaService.shared.sincronizar()

                    // Push: subir compras locales que no se pudieron sincronizar antes
                    await SyncService.shared.sincronizarPendientes(context: modelContext)

                    // Pull: descargar compras de la nube que no están en local
                    // (útil en nuevo dispositivo o reinstalación)
                    await SyncService.shared.pullDesdeSupabase(context: modelContext)
                }

                // Navegar a la pantalla principal después de 2.2 segundos
                // (independientemente de si las operaciones async terminaron)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    withAnimation(.easeInOut(duration: 0.3)) { showMain = true }
                }
            }
        }
    }
}
