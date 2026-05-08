// =============================================================================
// PerfilView.swift — Pantalla de perfil de usuario
// =============================================================================
// Rol en la app:
//   Muestra el resumen del perfil del usuario: avatar, nombre, email y plan
//   activo. También presenta estadísticas históricas (total de compras, monto
//   total gastado, ahorro estimado) y menús de navegación a funciones de cuenta,
//   objetivos y ajustes. Se navega desde el Tab "Perfil" en `MainTabView`.
//
// Equivalente Android:
//   Un `ProfileFragment` con `ConstraintLayout` que muestra datos del usuario
//   desde un `ProfileViewModel` que observa `UserRepository`. El menú de
//   opciones equivale a un `RecyclerView` con items tipo settings o a
//   `PreferenceFragment` de Jetpack.
//
// Avatar con fallback:
//   Si hay `avatarData` en `UserScopedStorage`, muestra la imagen real.
//   Si no, muestra un círculo con las iniciales del nombre. El `.task {}` de
//   la View sincroniza el avatar con Supabase Storage al aparecer la pantalla:
//   - Si no hay caché: descarga desde Supabase.
//   - Si hay caché: verifica si ya está subido a Supabase y lo sube si no.
//
// Logout:
//   Llama `SupabaseService.shared.logout()` en un `Task`. Esto invalida la
//   sesión JWT en Keychain y dispara el cambio en `SessionStore.authStateChanges`,
//   que redirige automáticamente a `LoginView` desde `SplashView`.
//   Equivalente Android: `FirebaseAuth.getInstance().signOut()` o
//   `viewModel.logout()` que limpia el token y navega al flujo de autenticación.
// =============================================================================

import SwiftUI
import SwiftData

/// Pantalla principal del perfil de usuario.
///
/// Equivalente Android: `ProfileFragment` con `ProfileViewModel` + `RecyclerView` de opciones.
struct PerfilView: View {

    // MARK: - Fuentes de datos

    /// Contexto de SwiftData — no se usa directamente para queries pero podría
    /// necesitarse para operaciones futuras (borrar datos del usuario, etc.).
    @Environment(\.modelContext) private var modelContext

    /// Todas las compras — se filtran por userId en la computed property `compras`.
    @Query(sort: \Compra.fecha, order: .reverse) private var todasCompras: [Compra]

    // MARK: - Estado de UI

    /// Controla si se presenta la hoja de ajustes.
    @State private var showSettings = false

    /// Controla si se presenta la hoja de edición de perfil.
    @State private var showEditar   = false

    /// Singleton de sesión — fuente de verdad del usuario autenticado.
    @State private var session = SessionStore.shared

    /// Preferencias de moneda y datos del usuario (nombre, email, avatar, etc.).
    @State private var store = UserScopedStorage.shared

    // MARK: - Datos del usuario

    /// Nombre del usuario activo desde `UserScopedStorage`.
    private var nombre:     String { store.nombre }

    /// Email del usuario activo desde `UserScopedStorage`.
    private var email:      String { store.email }

    /// Avatar del usuario como `Data` (imagen comprimida JPEG). Vacío si no hay foto.
    private var avatarData: Data   { store.avatarData }

    // MARK: - Compras del usuario

    /// Compras del usuario activo, filtradas por `userId` en memoria.
    private var compras: [Compra] {
        let uid = session.currentUserID
        guard !uid.isEmpty else { return [] }
        return todasCompras.filter { $0.userId == uid }
    }

    // MARK: - Métricas históricas

    /// Suma total de todas las compras del usuario (histórico completo).
    private var totalGastado:          Double { compras.reduce(0) { $0 + $1.total } }

    /// Número de supermercados distintos en los que el usuario ha comprado.
    private var supermercadosDistintos: Int   { Set(compras.map { $0.supermercado }).count }

    // MARK: - Iniciales del avatar

    /// Iniciales del nombre para mostrar cuando no hay avatar.
    /// Extrae la primera letra del primer nombre y del apellido (si existen).
    private var initials: String {
        let parts = nombre.split(separator: " ")
        if parts.count >= 2 {
            // "Juan Martínez" → "JM"
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        // Fallback: las primeras 2 letras del nombre, o "ML" si está vacío
        return nombre.prefix(2).uppercased().isEmpty ? "ML" : nombre.prefix(2).uppercased()
    }

    // MARK: - Altura de la barra de estado

    /// Altura dinámica de la barra de estado para el header.
    private var statusBarHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
            .first ?? 44
    }

    // MARK: - Vista principal

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // MARK: Header con gradiente verde
                    // `ZStack(alignment: .topTrailing)` para el círculo decorativo en esquina superior derecha
                    ZStack(alignment: .topTrailing) {
                        LinearGradient.saGreen  // Gradiente verde brand del DesignSystem

                        // Círculo decorativo semitransparente
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 280, height: 280)
                            .offset(x: 100, y: -100)

                        VStack(spacing: 0) {
                            Color.clear.frame(height: statusBarHeight)

                            HStack {
                                Text("Perfil")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(.white)
                                    .tracking(-0.6)
                                Spacer()
                                // Botón de ajustes — círculo semitransparente con ícono de engranaje
                                Button(action: { showSettings = true }) {
                                    Circle()
                                        .fill(Color.white.opacity(0.22))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Image(systemName: "gearshape")
                                                .font(.system(size: 18))
                                                .foregroundStyle(.white)
                                        )
                                }
                            }
                            .padding(.bottom, 28)

                            // MARK: Avatar + nombre + email
                            HStack(spacing: 14) {
                                // Avatar circular: imagen real o iniciales como fallback
                                // Equivalente Android: `CircleImageView` con Picasso/Glide,
                                // o `ShapeableImageView` con `cornerRadius`.
                                Group {
                                    if !avatarData.isEmpty, let uiImg = UIImage(data: avatarData) {
                                        // Imagen real desde los datos guardados en UserScopedStorage
                                        Image(uiImage: uiImg)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 72, height: 72)
                                            .clipShape(Circle())
                                            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                                    } else {
                                        // Fallback: círculo amarillo con las iniciales del nombre
                                        ZStack {
                                            Circle()
                                                .fill(LinearGradient(
                                                    colors: [Color(hex: "#FEF3C7"), Color(hex: "#FBBF24")],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ))
                                                .frame(width: 72, height: 72)
                                                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                                            Text(initials)
                                                .font(.system(size: 28, weight: .bold))
                                                .foregroundStyle(Color(hex: "#92400E"))
                                        }
                                    }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(nombre.isEmpty ? "Usuario" : nombre)
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(.white)
                                        .tracking(-0.6)
                                    Text(email.isEmpty ? "" : email)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white.opacity(0.9))

                                    // Badge de plan activo (Plan Pro)
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                        Text("Plan Pro")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                                    .background(Color.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 10))
                                    .padding(.top, 2)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 80)
                        }
                        .padding(.horizontal, 20)
                    }

                    // MARK: Card de estadísticas flotante
                    // `.offset(y: -40)` hace que la card "flote" sobre el header verde.
                    // Equivalente Android: un `CardView` con `layout_marginTop="-40dp"` para
                    // crear el efecto de superposición sobre el header.
                    SACard(padding: 0) {
                        HStack(spacing: 0) {
                            statCell(value: "\(compras.count)", label: "COMPRAS", green: false)
                            Divider().frame(height: 60)
                            statCell(value: store.convert(totalGastado).formatted(.currency(code: store.currencyCode)), label: "TOTAL HISTÓRICO", green: false, small: true)
                            Divider().frame(height: 60)
                            // El "ahorro" se estima como el 12% del total gastado (valor ilustrativo)
                            statCell(value: store.convert(totalGastado * 0.12).formatted(.currency(code: store.currencyCode)), label: "AHORRADO", green: true, small: true)
                        }
                    }
                    .padding(.horizontal, 20)
                    .offset(y: -40)   // Superponer sobre el header verde

                    // MARK: Contenido principal de la pantalla
                    VStack(spacing: 0) {

                        // Sección "Cuenta"
                        sectionLabel("Cuenta")
                        SACard(padding: 0) {
                            menuRow(icon: "person.fill", iconBg: Color.saGreen, title: "Editar perfil", isLast: false) {
                                showEditar = true
                            }
                            // Filas ilustrativas (sin funcionalidad real implementada)
                            menuRow(icon: "creditcard.fill", iconBg: Color(hex: "#8B5CF6"), title: "Métodos de pago", subtitle: "3 tarjetas guardadas", isLast: false) {}
                            menuRow(icon: "storefront.fill", iconBg: Color(hex: "#F97316"), title: "Tiendas favoritas", isLast: true) {}
                        }

                        // Sección "Objetivos" — barra de progreso de presupuesto mensual
                        sectionLabel("Objetivos").padding(.top, 22)
                        SACard {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.saGreenBg)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: "bookmark.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(Color.saGreen)
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Gasto mensual")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color.saLabel)
                                        .tracking(-0.3)
                                    // Ejemplo ilustrativo con presupuesto hardcodeado de $500.000
                                    Text("\(store.convert(totalGastado).formatted(.currency(code: store.currencyCode))) de \(store.convert(500000.0).formatted(.currency(code: store.currencyCode)))")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.saLabel3)
                                }
                                Spacer()
                                Text("\(Int(min(totalGastado / 500000 * 100, 100)))%")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Color.saGreen)
                            }

                            // Barra de progreso con GeometryReader para ancho proporcional
                            let progress = min(totalGastado / 500000, 1.0)  // Clampear al 100%
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4).fill(Color.saBg).frame(height: 8)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(LinearGradient(colors: [Color.saGreenLight, Color.saGreen], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: geo.size.width * CGFloat(progress), height: 8)
                                }
                            }
                            .frame(height: 8)
                            .padding(.top, 12)
                        }

                        // Sección "Más"
                        sectionLabel("Más").padding(.top, 22)
                        SACard(padding: 0) {
                            menuRow(icon: "square.and.arrow.up.fill", iconBg: Color(hex: "#06B6D4"), title: "Invitar amigos", subtitle: "Ganá 1 mes Pro gratis", isLast: false) {}
                            menuRow(icon: "gearshape.fill", iconBg: Color.saLabel3, title: "Ajustes", isLast: true) {
                                showSettings = true
                            }
                        }

                        // MARK: Botón de cierre de sesión
                        // `SupabaseService.shared.logout()` invalida el JWT y dispara
                        // `authStateChanges`, lo que redirige a LoginView automáticamente.
                        // Equivalente Android: `FirebaseAuth.getInstance().signOut()` + `navController.navigate(R.id.loginFragment)`.
                        Button {
                            Task { try? await SupabaseService.shared.logout() }
                        } label: {
                            Text("Cerrar sesión")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.saDanger)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.saCard, in: RoundedRectangle(cornerRadius: 14))
                                .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 24)
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 20)
                    .offset(y: -40)
                    .padding(.bottom, -40)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            // Recargar preferencias de moneda/nombre al aparecer la pantalla
            store.reload()
            let localData = store.avatarData
            if localData.isEmpty {
                // Sin caché local: intentar descargar el avatar desde Supabase Storage.
                // Equivalente Android: Glide/Coil cargando desde una URL remota.
                if let data = await SupabaseService.shared.fetchAvatarData() {
                    store.set(data, for: "avatarData")
                }
            } else {
                // Hay caché local: verificar si ya está sincronizado a Supabase.
                // Si `avatar_url` es NULL en la tabla perfiles, subir la imagen ahora.
                if let perfil = try? await SupabaseService.shared.fetchPerfil(),
                   perfil.avatarURL == nil,
                   let url = try? await SupabaseService.shared.subirAvatar(localData) {
                    let nombre = store.nombre.isEmpty ? perfil.nombre : store.nombre
                    try? await SupabaseService.shared.guardarPerfil(nombre: nombre, avatarURL: url)
                }
            }
        }
        // Hoja de ajustes
        .sheet(isPresented: $showSettings) { SettingsView() }
        // Hoja de edición de perfil — al cerrar, recargar los datos del store
        .sheet(isPresented: $showEditar, onDismiss: { store.reload() }) {
            EditarPerfilView()
        }
    }

    // MARK: - Celda de estadística

    /// Celda de estadística con valor y etiqueta, usada en la card flotante de 3 columnas.
    ///
    /// - Parameters:
    ///   - value: El valor a mostrar (ej: "42" o "$1.500,00").
    ///   - label: Etiqueta en mayúsculas debajo del valor.
    ///   - green: Si `true`, colorea el valor en verde (para "AHORRADO").
    ///   - small: Si `true`, usa fuente más pequeña para valores extensos.
    @ViewBuilder
    private func statCell(value: String, label: String, green: Bool, small: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: small ? 15 : 22, weight: .bold))
                .foregroundStyle(green ? Color.saGreen : Color.saLabel)
                .tracking(-0.4)
                .lineLimit(1)
                .minimumScaleFactor(0.7)  // Comprime el texto antes de truncar
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.saLabel3)
                .tracking(0.1)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
    }

    // MARK: - Etiqueta de sección

    /// Etiqueta de sección en mayúsculas estilo iOS Settings.
    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.saLabel3)
            .tracking(0.2)
            .padding(.horizontal, 4)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Fila de menú

    /// Fila de menú estilo iOS Settings con ícono, título opcional, subtítulo y chevron.
    ///
    /// Equivalente Android: ítem de `PreferenceFragment` o fila de `RecyclerView` con
    /// `ViewHolder` que tiene ícono, título, subtítulo y flecha.
    ///
    /// - Parameters:
    ///   - icon: SF Symbol name para el ícono.
    ///   - iconBg: Color de fondo del ícono.
    ///   - title: Título principal de la fila.
    ///   - subtitle: Texto secundario opcional (ej: "3 tarjetas guardadas").
    ///   - isLast: Si `true`, no dibuja el separador inferior.
    ///   - action: Closure ejecutada al tocar la fila.
    @ViewBuilder
    private func menuRow(icon: String, iconBg: Color, title: String, subtitle: String? = nil, isLast: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(iconBg)
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.saLabel)
                    if let sub = subtitle {
                        Text(sub)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.saLabel3)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.saLabel4)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 60)
            .overlay(alignment: .bottom) {
                // Separador entre filas (excepto la última)
                if !isLast {
                    Rectangle().fill(Color.saSep).frame(height: 0.5).padding(.leading, 62)
                }
            }
            .contentShape(Rectangle())  // Área táctil del botón ocupa toda la fila
        }
        .buttonStyle(.plain)
    }
}
