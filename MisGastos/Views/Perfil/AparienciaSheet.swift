// =============================================================================
// AparienciaSheet.swift — Selector de apariencia visual (Claro / Oscuro / Sistema)
// =============================================================================
// Rol en la app:
//   Sheet presentada desde `SettingsView` que permite al usuario elegir el tema
//   visual de la app: Claro (fuerza light mode), Oscuro (fuerza dark mode) o
//   Sistema (sigue la configuración del dispositivo). La selección se persiste
//   en `@AppStorage("aparienciaMode")` y se sincroniza con Supabase para
//   restaurar la preferencia al iniciar sesión en otro dispositivo.
//   `SplashView` aplica el `colorScheme` correspondiente a toda la jerarquía.
//
// Equivalente Android:
//   `AppCompatDelegate.setDefaultNightMode()` con valores:
//     - `MODE_NIGHT_NO`     → equivalente a "claro"
//     - `MODE_NIGHT_YES`    → equivalente a "oscuro"
//     - `MODE_NIGHT_FOLLOW_SYSTEM` → equivalente a "sistema"
//   La preferencia se guarda en `SharedPreferences` y se restaura en `Application.onCreate()`.
//
// `AparienciaMode` enum:
//   El enum `String, CaseIterable` es la fuente de verdad de todos los modos posibles.
//   `rawValue` es el string guardado en `@AppStorage` y en Supabase.
//   `colorScheme: ColorScheme?` — retorna el valor que se pasa a `.preferredColorScheme()`
//   en SwiftUI (nil = sigue al sistema, que es el comportamiento por defecto).
//
// Mockups de teléfono:
//   Los mockups son vistas SwiftUI puras (sin imágenes externas) que simulan la apariencia
//   de la app en cada modo. El modo "Sistema" usa `SistemaTriangle` (un `Shape` custom)
//   para dividir el fondo en mitad clara / mitad oscura con un triángulo diagonal.
// =============================================================================

import SwiftUI

// MARK: - Enum AparienciaMode (accesible en todo el módulo)

/// Enum que representa los tres modos de apariencia visual disponibles en la app.
///
/// Equivalente Android: los valores de `AppCompatDelegate.NightMode`.
/// Está declarado a nivel de módulo (fuera de la struct) para que `SplashView`,
/// `SettingsView` y `AparienciaSheet` puedan usarlo sin importaciones adicionales.
enum AparienciaMode: String, CaseIterable {
    case claro   = "claro"
    case oscuro  = "oscuro"
    case sistema = "sistema"

    /// Nombre de display en español para mostrar en la UI.
    var label: String {
        switch self {
        case .claro:   return "Claro"
        case .oscuro:  return "Oscuro"
        case .sistema: return "Sistema"
        }
    }

    /// Descripción secundaria del comportamiento de cada modo.
    var sublabel: String {
        switch self {
        case .claro:   return "Siempre claro"
        case .oscuro:  return "Siempre oscuro"
        case .sistema: return "Sigue al sistema"
        }
    }

    /// `ColorScheme` de SwiftUI correspondiente al modo.
    ///
    /// Se pasa a `.preferredColorScheme(_:)` en `SplashView` para forzar el tema.
    /// `nil` equivale a no forzar ningún tema (hereda del sistema).
    /// Equivalente Android: el valor del Night Mode a pasar a `AppCompatDelegate`.
    var colorScheme: ColorScheme? {
        switch self {
        case .claro:   return .light  // Fuerza modo claro independientemente del sistema
        case .oscuro:  return .dark   // Fuerza modo oscuro independientemente del sistema
        case .sistema: return nil     // nil = SwiftUI hereda el scheme del dispositivo
        }
    }
}

// MARK: - Sheet de selección de apariencia

/// Sheet que muestra mockups de teléfono para elegir el modo visual de la app.
///
/// Equivalente Android: un `BottomSheetDialogFragment` con tres opciones ilustradas
/// y `RadioButton` para la selección.
struct AparienciaSheet: View {

    // MARK: - Estado persisted

    /// Modo de apariencia activo persistido en `UserDefaults` via `@AppStorage`.
    /// Cuando cambia, `SplashView` lo detecta y aplica el nuevo `colorScheme`.
    @AppStorage("aparienciaMode") private var modeRaw: String = "sistema"

    /// Permite cerrar el bottom sheet.
    @Environment(\.dismiss) private var dismiss

    // MARK: - Modo actual

    /// Modo activo como enum tipado (para comparaciones y lógica de UI).
    private var current: AparienciaMode { AparienciaMode(rawValue: modeRaw) ?? .sistema }

    // MARK: - Vista principal

    var body: some View {
        VStack(spacing: 0) {
            // Pastilla indicadora de bottom sheet (estilo iOS)
            Capsule()
                .fill(Color.saLabel4)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Text("Apariencia")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.saLabel)
                .tracking(-0.4)

            Text("Elegí el estilo visual de Súper Ahorro")
                .font(.system(size: 14))
                .foregroundStyle(Color.saLabel3)
                .padding(.top, 4)
                .padding(.bottom, 28)

            // MARK: Mockups de teléfono — vista previa visual de cada modo
            // `ForEach` sobre `AparienciaMode.allCases` asegura que si se agrega un modo
            // nuevo, aparezca automáticamente sin modificar la UI.
            HStack(spacing: 16) {
                ForEach(AparienciaMode.allCases, id: \.rawValue) { mode in
                    modeCard(mode)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)

            // MARK: Lista de opciones con label y sublabel
            SACard(padding: 0) {
                ForEach(Array(AparienciaMode.allCases.enumerated()), id: \.element.rawValue) { idx, mode in
                    listRow(mode: mode, isLast: idx == 2)  // El último no tiene separador
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color.saBg.ignoresSafeArea())
    }

    // MARK: - Card de mockup

    /// Card con mockup de teléfono, etiqueta y radio button para cada modo.
    ///
    /// Al tocar, llama `select(_:)` que persiste el modo y sincroniza con Supabase.
    @ViewBuilder
    private func modeCard(_ mode: AparienciaMode) -> some View {
        let isSelected = current == mode
        Button {
            select(mode)
        } label: {
            VStack(spacing: 10) {
                // Mockup de teléfono con borde verde si está seleccionado
                phoneMockup(mode: mode, isSelected: isSelected)
                    .frame(width: 88, height: 124)

                Text(mode.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.saLabel)

                // Radio button circular (verde si seleccionado, gris si no)
                radioButton(isSelected: isSelected)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mockup de teléfono

    /// Mockup simplificado de un teléfono que muestra la apariencia del modo.
    ///
    /// Usa vistas SwiftUI puras (sin imágenes) para simular el diseño de la app:
    /// una pastilla de Dynamic Island, un círculo de avatar verde y tres cards.
    @ViewBuilder
    private func phoneMockup(mode: AparienciaMode, isSelected: Bool) -> some View {
        ZStack {
            phoneBg(mode)         // Fondo del teléfono según el modo
            phoneForeground(mode) // Elementos decorativos (pastilla, cards)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                // Borde verde resaltado si está seleccionado, gris si no
                .stroke(isSelected ? Color.saGreen : Color.saSep,
                        lineWidth: isSelected ? 2.5 : 1)
        )
        .shadow(color: .black.opacity(0.07), radius: 8, y: 3)
    }

    /// Fondo del mockup del teléfono según el modo de apariencia.
    ///
    /// El modo "Sistema" usa `SistemaTriangle` (ver abajo) para dividir el fondo
    /// en mitad blanca (izquierda-arriba) y mitad oscura (derecha-abajo) con un
    /// triángulo diagonal. Equivalente a mostrar ambos temas simultáneamente.
    @ViewBuilder
    private func phoneBg(_ mode: AparienciaMode) -> some View {
        switch mode {
        case .claro:
            Color.white
        case .oscuro:
            Color(hex: "#1C1C1E")  // Color de fondo oscuro de iOS (systemBackground en dark mode)
        case .sistema:
            ZStack {
                Color.white
                // Triángulo oscuro en la esquina inferior derecha — representa el modo oscuro
                Color(hex: "#1C1C1E").clipShape(SistemaTriangle())
            }
        }
    }

    /// Elementos decorativos del mockup: pastilla, punto verde (avatar) y cards.
    @ViewBuilder
    private func phoneForeground(_ mode: AparienciaMode) -> some View {
        VStack(spacing: 7) {
            // Simulación de la pastilla de Dynamic Island/notch
            RoundedRectangle(cornerRadius: 3)
                .fill(pillColor(mode))
                .frame(width: 26, height: 5)
            // Simulación de un avatar circular verde
            Circle()
                .fill(Color.saGreen)
                .frame(width: 8, height: 8)
            // Tres cards decorativas que simulan el contenido de la app
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 6)
                    .fill(cardColor(mode))
                    .frame(height: 16)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    /// Color de la pastilla (Dynamic Island) según el modo — contrasta con el fondo.
    private func pillColor(_ mode: AparienciaMode) -> Color {
        switch mode {
        case .claro:   return Color.black.opacity(0.15)   // Pastilla gris sobre fondo blanco
        case .oscuro:  return Color.white.opacity(0.25)   // Pastilla blanca sobre fondo oscuro
        case .sistema: return Color.gray.opacity(0.4)     // Neutral para fondo mitad/mitad
        }
    }

    /// Color de las cards decorativas según el modo.
    private func cardColor(_ mode: AparienciaMode) -> Color {
        switch mode {
        case .claro:   return Color.black.opacity(0.08)   // Sombra leve sobre fondo blanco
        case .oscuro:  return Color.white.opacity(0.10)   // Tinte claro sobre fondo oscuro
        case .sistema: return Color.gray.opacity(0.18)    // Neutral
        }
    }

    // MARK: - Radio button

    /// Radio button circular: verde con checkmark si seleccionado, gris outline si no.
    ///
    /// Equivalente Android: `RadioButton` de Material Design.
    @ViewBuilder
    private func radioButton(isSelected: Bool) -> some View {
        ZStack {
            if isSelected {
                Circle().fill(Color.saGreen).frame(width: 24, height: 24)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle().stroke(Color.saLabel4, lineWidth: 1.5).frame(width: 24, height: 24)
            }
        }
    }

    // MARK: - Fila de lista

    /// Fila de lista con label, sublabel y checkmark si está seleccionado.
    ///
    /// Equivalente Android: fila de `RadioGroup` con `RadioButton` a la derecha.
    @ViewBuilder
    private func listRow(mode: AparienciaMode, isLast: Bool) -> some View {
        let isSelected = current == mode
        Button { select(mode) } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.label)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.saLabel)
                    Text(mode.sublabel)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.saLabel3)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.saGreen)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 60)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle().fill(Color.saSep).frame(height: 0.5).padding(.leading, 16)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Acción de selección

    /// Persiste el modo elegido en `@AppStorage` y lo sincroniza con Supabase.
    ///
    /// `withAnimation` aplica transición suave al cambiar el borde del mockup seleccionado.
    /// `Task.detached` ejecuta la sincronización en background sin bloquear la UI.
    /// Si falla la sincronización, `@AppStorage` ya tiene el valor correcto y se
    /// sincronizará en el próximo inicio de sesión.
    private func select(_ mode: AparienciaMode) {
        withAnimation(.easeInOut(duration: 0.2)) { modeRaw = mode.rawValue }
        let raw = mode.rawValue
        // Sincronizar con Supabase en background — no bloquea la UI
        Task.detached { try? await SupabaseService.shared.guardarApariencia(raw) }
    }
}

// MARK: - Shape para el mockup del modo "Sistema"

/// Shape que dibuja un triángulo en la esquina inferior derecha del rectángulo contenedor.
///
/// Se usa para dividir el fondo del mockup del modo "Sistema" en:
///   - Mitad superior-izquierda: fondo blanco (modo claro)
///   - Mitad inferior-derecha: fondo oscuro (cubierta por este triángulo)
///
/// Equivalente Android: un `View` con `Canvas.drawPath()` personalizado o
/// un `ClipPath` en XML con `pathData` triangular.
private struct SistemaTriangle: Shape {
    /// Dibuja un triángulo rectángulo que ocupa la esquina inferior derecha del rect.
    ///
    /// Los tres vértices son:
    ///   - `(maxX, minY)` — esquina superior derecha
    ///   - `(maxX, maxY)` — esquina inferior derecha
    ///   - `(minX, maxY)` — esquina inferior izquierda
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))     // Esquina superior derecha
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))  // Esquina inferior derecha
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))  // Esquina inferior izquierda
        p.closeSubpath()  // Cierra el triángulo volviendo al punto de inicio
        return p
    }
}
