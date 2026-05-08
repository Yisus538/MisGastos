// =============================================================================
// SettingsView.swift — Pantalla de ajustes de la aplicación
// =============================================================================
// Rol en la app:
//   Sheet con todas las configuraciones del usuario: moneda, idioma, apariencia,
//   OCR automático de tickets, presupuesto mensual, opciones de datos y membresía.
//   Se navega desde `PerfilView` al tocar el ícono de engranaje.
//
// Equivalente Android:
//   `SettingsFragment` (Jetpack) con `PreferenceScreen` y `PreferenceCategory`.
//   `@AppStorage` equivale a `SharedPreferences` o `DataStore<Preferences>`.
//   Los `confirmationDialog` equivalen a `AlertDialog` o `BottomSheetDialogFragment`.
//
// `@AppStorage` vs `UserScopedStorage`:
//   - `@AppStorage("aparienciaMode")` es un booleano global (no por usuario) porque
//     la apariencia visual se aplica a nivel de app, no de cuenta.
//   - `@AppStorage("ocrAutomatico")` también es global: solo hay un dispositivo.
//   - `store` (UserScopedStorage) se usa para la moneda y el presupuesto, que
//     son POR USUARIO: cada cuenta tiene su propia configuración almacenada con
//     prefijo `{userId}_{clave}` en UserDefaults.
//
// NotificationService:
//   La clase `NotificationService` se define al final de este archivo por deuda
//   técnica (debería estar en `Services/NotificationService.swift`). Gestiona
//   permisos de notificaciones locales y programa un recordatorio semanal usando
//   `UNUserNotificationCenter`. Equivalente Android: `NotificationManager` +
//   `AlarmManager` o `WorkManager` para notificaciones periódicas.
// =============================================================================

import SwiftUI

/// Pantalla de ajustes de la aplicación.
///
/// Equivalente Android: `SettingsFragment` con `PreferenceScreen` de Jetpack Preferences.
struct SettingsView: View {

    // MARK: - Preferencias globales (AppStorage)

    /// Modo de apariencia: "claro", "oscuro" o "sistema".
    /// `@AppStorage` persiste en `UserDefaults.standard` automáticamente.
    /// Equivalente Android: `SharedPreferences.getString("apariencia", "sistema")`.
    @AppStorage("aparienciaMode") private var aparienciaRaw: String = "sistema"

    /// Si `true`, el OCR de tickets se ejecuta automáticamente al adjuntar una foto.
    @AppStorage("ocrAutomatico")  private var ocrAutomatico: Bool   = true

    // MARK: - Estado de UI

    /// Controla la presentación del selector de apariencia.
    @State private var showApariencia   = false

    /// Controla el diálogo de selección de moneda.
    @State private var showMoneda       = false

    /// Controla el diálogo de selección de idioma.
    @State private var showIdioma       = false

    /// Controla la presentación de la pantalla de membresía.
    @State private var showMembresia    = false

    /// Controla el alert de reinicio por cambio de idioma.
    @State private var showRestartAlert = false

    /// Texto del campo de presupuesto mensual (editable, se parsea a `Double` al cambiar).
    @State private var presupuestoStr   = ""

    /// Permite cerrar la sheet.
    @Environment(\.dismiss) private var dismiss

    /// Preferencias de usuario para moneda, presupuesto y plan.
    @State private var store = UserScopedStorage.shared

    // MARK: - Datos de monedas e idiomas disponibles

    /// Monedas soportadas: código ISO 4217, nombre en español y emoji de bandera.
    private let monedas: [(code: String, label: String, flag: String)] = [
        ("ARS", "Peso argentino", "🇦🇷"),
        ("USD", "Dólar", "🇺🇸"),
        ("EUR", "Euro", "🇪🇺"),
        ("BRL", "Real brasileño", "🇧🇷"),
    ]

    /// Idiomas disponibles: código BCP-47, nombre en español y emoji de bandera.
    private let idiomas: [(code: String, label: String, flag: String)] = [
        ("es", "Español", "🇦🇷"),
        ("en", "English", "🇺🇸"),
    ]

    // MARK: - Labels derivados del estado actual

    /// Etiqueta del modo de apariencia activo (ej: "Claro", "Oscuro", "Sistema").
    private var aparienciaLabel: String {
        (AparienciaMode(rawValue: aparienciaRaw) ?? .sistema).label
    }

    /// Etiqueta de la moneda activa con emoji (ej: "🇦🇷 ARS").
    private var monedaLabel: String {
        monedas.first { $0.code == store.currencyCode }.map { "\($0.flag) \($0.code)" } ?? "🇦🇷 ARS"
    }

    /// Etiqueta del idioma activo con emoji (ej: "🇦🇷 Español").
    private var idiomaLabel: String {
        idiomas.first { $0.code == store.languageCode }.map { "\($0.flag) \($0.label)" } ?? "🇦🇷 Español"
    }

    // MARK: - Binding manual para presupuesto activo en UserScopedStorage

    /// Binding que conecta el Toggle de presupuesto con `UserScopedStorage`.
    /// Se crea manualmente porque `UserScopedStorage` no es un `@State`/`@Binding`
    /// nativo: el `get` lee el valor actual, el `set` lo persiste.
    /// Equivalente Android: `dataStore.edit { it[KEY] = newValue }` en `ViewModel`.
    private var presupuestoActivoBinding: Binding<Bool> {
        Binding(
            get: { store.presupuestoActivo },
            set: { store.set($0, for: "presupuestoActivo") }
        )
    }

    // MARK: - Vista principal

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Barra de navegación (botón Perfil)
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.saGreen)
                            Text("Perfil")
                                .font(.system(size: 17))
                                .foregroundStyle(Color.saGreen)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Ajustes")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color.saLabel)
                            .tracking(-1)
                            .padding(.top, 10)
                            .padding(.bottom, 20)

                        // MARK: Fila de membresía (tarjeta verde especial)
                        membresiaRow
                            .padding(.bottom, 22)

                        // MARK: Sección General — moneda e idioma
                        sectionLabel("General")
                        SACard(padding: 0) {
                            buttonRow(icon: "tag.fill", iconBg: Color.saGreen,
                                      title: "Moneda", value: monedaLabel, isLast: false) {
                                showMoneda = true
                            }
                            buttonRow(icon: "globe", iconBg: Color(hex: "#0A84FF"),
                                      title: "Idioma", value: idiomaLabel, isLast: true) {
                                showIdioma = true
                            }
                        }

                        // MARK: Sección Apariencia — navega a AparienciaSheet
                        sectionLabel("Apariencia").padding(.top, 22)
                        SACard(padding: 0) {
                            buttonRow(icon: "eye.fill", iconBg: Color(hex: "#6366F1"),
                                      title: "Apariencia", value: aparienciaLabel, isLast: true) {
                                showApariencia = true
                            }
                        }

                        // MARK: Sección Compras — OCR y presupuesto mensual
                        sectionLabel("Compras").padding(.top, 22)
                        SACard(padding: 0) {
                            // Toggle de OCR automático: activa/desactiva el análisis de imagen al adjuntar ticket
                            toggleRow(
                                icon: "sparkles",
                                iconBg: Color(hex: "#FF9500"),
                                title: "OCR automático de tickets",
                                binding: $ocrAutomatico,
                                isLast: false
                            )
                            // Toggle de presupuesto mensual — usa binding manual al UserScopedStorage
                            toggleRow(
                                icon: "banknote",
                                iconBg: Color.saGreen,
                                title: "Presupuesto mensual",
                                binding: presupuestoActivoBinding,
                                isLast: !store.presupuestoActivo  // Es la última si el campo de monto está oculto
                            )
                            // Campo de monto del presupuesto — solo visible cuando el toggle está activo
                            if store.presupuestoActivo {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8).fill(Color.saGreen)
                                        Image(systemName: "dollarsign")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.white)
                                    }
                                    .frame(width: 32, height: 32)
                                    // TextField de monto — filtra caracteres no numéricos en tiempo real
                                    TextField("Límite mensual en \(store.currencyCode)", text: $presupuestoStr)
                                        .keyboardType(.decimalPad)
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color.saLabel)
                                        .onChange(of: presupuestoStr) { _, v in
                                            // Filtrar: solo números, punto y coma
                                            let clean = v.filter { $0.isNumber || $0 == "." || $0 == "," }
                                            presupuestoStr = clean
                                            // Parsear y guardar en UserScopedStorage (con scope de usuario)
                                            if let val = Double(clean.replacingOccurrences(of: ",", with: ".")) {
                                                store.set(val, for: "presupuestoMensual")
                                            }
                                        }
                                    Spacer()
                                    // Preview del presupuesto formateado en la moneda elegida
                                    if store.presupuestoMensual > 0 {
                                        Text(store.presupuestoMensual.formatted(.currency(code: store.currencyCode)))
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.saLabel3)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .frame(minHeight: 50)
                            }
                        }

                        // MARK: Sección Datos
                        sectionLabel("Datos").padding(.top, 22)
                        SACard(padding: 0) {
                            plainRow(icon: "doc.plaintext.fill", iconBg: Color.saLabel3, title: "Exportar historial", value: nil, isLast: false)
                            plainRow(icon: "bookmark.fill", iconBg: Color(hex: "#10B981"), title: "Respaldo en la nube", value: nil, isLast: false)
                            plainRow(icon: "trash.fill", iconBg: Color.saDanger, title: "Borrar todos los datos", value: nil, isLast: true)
                        }

                        // MARK: Sección Sobre — información de la app
                        sectionLabel("Sobre").padding(.top, 22)
                        SACard(padding: 0) {
                            plainRow(icon: nil, iconBg: nil, title: "Ayuda y soporte", value: nil, isLast: false)
                            plainRow(icon: nil, iconBg: nil, title: "Términos de servicio", value: nil, isLast: false)
                            plainRow(icon: nil, iconBg: nil, title: "Política de privacidad", value: nil, isLast: false)
                            HStack {
                                Text("Versión")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.saLabel)
                                Spacer()
                                Text("1.0.0")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.saLabel3)
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 50)
                        }

                        // MARK: Botón de cierre de sesión
                        // Equivalente Android: `authViewModel.logout()` que limpia tokens
                        // y navega a `LoginActivity` con `Intent.FLAG_ACTIVITY_CLEAR_TASK`.
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
                }
            }
        }
        .onAppear {
            // Pre-cargar el texto del presupuesto desde el store al abrir la pantalla
            let val = store.presupuestoMensual
            if val > 0 {
                // Mostrar sin decimales si es entero, con .2f si tiene centavos
                presupuestoStr = val.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(val))
                    : String(format: "%.2f", val)
            }
        }
        .sheet(isPresented: $showMembresia)  { MembresiaView() }
        .sheet(isPresented: $showApariencia) { AparienciaSheet() }
        // `confirmationDialog` en iOS equivale a `AlertDialog` en Android con lista de opciones.
        // En iPhone aparece como Action Sheet desde abajo; en iPad como popover.
        .confirmationDialog("Seleccioná la moneda", isPresented: $showMoneda, titleVisibility: .visible) {
            ForEach(monedas, id: \.code) { m in
                Button("\(m.flag) \(m.label) (\(m.code))") {
                    // `setCurrencyCode` actualiza UserScopedStorage y recarga tasas de cambio
                    store.setCurrencyCode(m.code)
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .confirmationDialog("Seleccioná el idioma", isPresented: $showIdioma, titleVisibility: .visible) {
            ForEach(idiomas, id: \.code) { i in
                Button("\(i.flag) \(i.label)") {
                    store.setLanguageCode(i.code)
                    showRestartAlert = true  // El cambio de idioma requiere reiniciar la app
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .alert("Idioma actualizado", isPresented: $showRestartAlert) {
            Button("Entendido") {}
        } message: {
            Text("Cerrá y volvé a abrir la app para aplicar el nuevo idioma.")
        }
    }

    // MARK: - Fila de membresía

    /// Fila especial con gradiente verde para mostrar el plan actual y navegar a `MembresiaView`.
    @ViewBuilder
    private var membresiaRow: some View {
        Button { showMembresia = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.22))
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    // Título dinámico según el plan activo
                    Text(store.planActivo == "pro" ? "Súper Ahorro+ Pro" : "Súper Ahorro+")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    // Subtítulo: fecha de renovación o call-to-action para upgrading
                    Text(renovacionLabel)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(LinearGradient.saGreen, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.saGreen.opacity(0.35), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    /// Texto descriptivo del estado de renovación o de plan gratuito.
    private var renovacionLabel: String {
        if store.planActivo == "pro", let fecha = store.fechaRenovacion {
            let str = fecha.formatted(.dateTime.day().month(.abbreviated))
            return "Renovación: \(str) · Gestionar plan"
        }
        return "Gratis · Mejorar a Pro"
    }

    // MARK: - Constructores de filas

    /// Etiqueta de sección en mayúsculas (ej: "GENERAL").
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

    /// Fila de solo lectura con ícono opcional y valor opcional.
    /// Se usa para filas sin acción implementada (ej: exportar, borrar datos).
    @ViewBuilder
    private func plainRow(icon: String?, iconBg: Color?, title: String, value: String?, isLast: Bool) -> some View {
        HStack(spacing: 14) {
            if let icon, let bg = iconBg {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(bg)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                }
                .frame(width: 32, height: 32)
            }
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Color.saLabel)
            Spacer()
            if let value {
                Text(value)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.saLabel3)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.saLabel4)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(Color.saSep).frame(height: 0.5)
                    .padding(.leading, icon != nil ? 62 : 16)  // Sangría según si hay ícono
            }
        }
    }

    /// Fila con `Toggle` (switch) para opciones booleanas.
    ///
    /// Equivalente Android: fila de `PreferenceFragment` con `SwitchPreference`,
    /// o un `RecyclerView` con un `SwitchCompat` en el `ViewHolder`.
    @ViewBuilder
    private func toggleRow(icon: String, iconBg: Color, title: String, binding: Binding<Bool>, isLast: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(iconBg)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Color.saLabel)
            Spacer()
            // `.tint(Color.saGreen)` colorea el toggle activo con el color verde brand
            Toggle("", isOn: binding).tint(Color.saGreen).labelsHidden()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(Color.saSep).frame(height: 0.5).padding(.leading, 62)
            }
        }
    }

    /// Fila con ícono, título, valor actual y chevron — dispara una acción al tocar.
    /// Usada para opciones que abren otra pantalla o dialog (moneda, idioma, apariencia).
    @ViewBuilder
    private func buttonRow(icon: String, iconBg: Color, title: String, value: String, isLast: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(iconBg)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                }
                .frame(width: 32, height: 32)
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.saLabel)
                Spacer()
                Text(value)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.saLabel3)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.saLabel4)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle().fill(Color.saSep).frame(height: 0.5).padding(.leading, 62)
                }
            }
            .contentShape(Rectangle())  // Área táctil de toda la fila
        }
        .buttonStyle(.plain)
    }
}

// MARK: - NotificationService

/// Servicio de notificaciones locales del sistema.
///
/// Deuda técnica: este servicio está definido en el mismo archivo que `SettingsView`
/// porque fue añadido durante el mismo ciclo de implementación. Debería moverse a
/// `Services/NotificationService.swift` en una refactorización futura.
///
/// Equivalente Android:
///   - `NotificationManager` + `NotificationChannel` para crear notificaciones.
///   - `AlarmManager.setRepeating()` o `WorkManager` con `PeriodicWorkRequest`
///     para programar notificaciones periódicas.
///   - `requestPermissions()` equivale a `ActivityResultContracts.RequestPermission`
///     con `POST_NOTIFICATIONS` (requerido desde Android 13/API 33).
final class NotificationService {

    /// Singleton compartido — un solo punto de acceso al servicio.
    static let shared = NotificationService()

    /// Solicita permiso para mostrar notificaciones al usuario.
    ///
    /// `requestAuthorization(options:)` muestra el diálogo de permiso del sistema
    /// la primera vez. Si el usuario ya respondió, devuelve el estado actual sin mostrar nada.
    /// Equivalente Android: `ActivityResultLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)`.
    ///
    /// - Returns: `true` si el usuario concedió permiso; `false` si lo denegó o hubo error.
    func solicitarPermiso() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Programa un recordatorio semanal para registrar compras.
    ///
    /// Usa `UNCalendarNotificationTrigger` con `DateComponents` para disparar en un
    /// día de la semana y hora específicos. `repeats: true` hace que se repita cada semana.
    /// Equivalente Android: `WorkManager.enqueueUniquePeriodicWork()` con
    /// `PeriodicWorkRequest.Builder(NotificationWorker::class, 7, TimeUnit.DAYS)`.
    ///
    /// - Parameters:
    ///   - diaSemana: Día de la semana (2 = lunes, según `Calendar`). Default: 2 (lunes).
    ///   - hora: Hora del día en formato 24h. Default: 10 (10:00 AM).
    func programarRecordatorio(diaSemana: Int = 2, hora: Int = 10) {
        let content = UNMutableNotificationContent()
        content.title = "Súper Ahorro"
        content.body = "¿Hiciste compras esta semana? ¡Registralas ahora!"
        content.sound = .default  // Sonido estándar del sistema

        // DateComponents define cuándo dispara el trigger
        var dc = DateComponents()
        dc.weekday = diaSemana  // Día de la semana (1=domingo, 2=lunes, ..., 7=sábado)
        dc.hour = hora
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)

        // Agregar la notificación a la cola del sistema con un identificador único
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "recordatorio-semanal", content: content, trigger: trigger)
        )
    }
}
