// =============================================================================
// GastosMesIntent.swift — Integración con Siri y Atajos de iOS (AppIntents)
// =============================================================================
// Rol en la app:
//   Implementa un "Atajo de Siri" que permite al usuario consultar cuánto
//   gastó este mes sin abrir la app. El usuario puede activarlo diciendo frases
//   como "¿Cuánto gasté este mes en Súper Ahorro?" y Siri responde con el
//   total del mes, la cantidad de compras y un snippet visual de la app.
//
// Equivalente Android:
//   En Android, la integración con el asistente de Google se hace vía:
//   - `App Actions` (acciones declaradas en `shortcuts.xml`).
//   - `Slices API` (fragmentos de UI de la app embebidos en Google Search).
//   - En Compose: no hay equivalente directo tan integrado como AppIntents en iOS.
//
// Framework: AppIntents (iOS 16+)
//   Reemplaza al antiguo `SiriKit Intents` framework (archivos `.intentdefinition`).
//   AppIntents usa Swift puro en lugar de XML + clases generadas por Xcode.
//   Los intents se registran automáticamente por el sistema — no requiere archivos
//   adicionales de configuración.
//
// Flujo de ejecución del Intent:
//   1. Usuario dice una de las frases registradas en `SuperAhorroShortcuts`.
//   2. Siri reconoce la frase y llama a `GastosMesIntent.perform()`.
//   3. `perform()` lee los datos del App Group UserDefaults (compartido con el widget).
//   4. Retorna un `IntentResult` con un `IntentDialog` (texto para que Siri lea en voz alta)
//      y una vista SwiftUI (`GastosMesSnippet`) que se muestra en la interfaz de Siri.
//
// Por qué se leen del App Group:
//   El proceso de AppIntents corre fuera del contexto de la app principal,
//   similar a la extensión del Widget. El App Group UserDefaults (`suiteName: "group.xxx"`)
//   es el único mecanismo que permite compartir datos entre estos procesos.
//   `HomeView.writeWidgetData()` actualiza estos datos cada vez que cambian las compras.
// =============================================================================

import AppIntents
import Foundation

// MARK: - Intent

/// Intent de Siri que consulta el gasto del mes actual.
///
/// `AppIntent` es el protocolo base de AppIntents framework (iOS 16+).
/// Equivalente Android: una `App Action` declarada en `shortcuts.xml` con
/// built-in intent `actions.intent.GET_ACCOUNT_BALANCE` o un intent personalizado.
///
/// `ProvidesDialog` → Siri puede leer la respuesta en voz alta.
/// `ShowsSnippetView` → Siri muestra una vista SwiftUI de la app embebida en su UI.
struct GastosMesIntent: AppIntent {

    /// Título del intent — aparece en la app Atajos de iPhone y en la UI de Siri.
    static var title: LocalizedStringResource = "Gasto del mes"

    /// Descripción que aparece en la app Atajos al explorar acciones disponibles.
    static var description = IntentDescription(
        "Consulta cuánto gastaste este mes en el supermercado.",
        categoryName: "Consultas"
    )

    /// `false` indica que Siri no necesita abrir la app para ejecutar el intent.
    /// El intent se ejecuta en background y responde directamente en la UI de Siri.
    /// Si fuera `true`, Siri abriría la app y esperaría que devuelva un resultado.
    static var openAppWhenRun: Bool = false

    /// Ejecuta el intent y devuelve el resultado al sistema.
    ///
    /// Lee los datos del App Group UserDefaults, que `HomeView` actualiza cada
    /// vez que cambian las compras del mes mediante `WidgetDataWriter.write(...)`.
    ///
    /// Retorna:
    /// - `IntentDialog`: texto que Siri lee en voz alta.
    /// - `GastosMesSnippet`: vista SwiftUI mostrada en la UI de Siri/Atajos.
    ///
    /// `throws` porque los intents pueden fallar (permisos, datos faltantes, etc.).
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        // Leer datos del App Group compartido con el Widget
        let ud           = UserDefaults(suiteName: "group.com.undef.superahorro")
        let total        = ud?.double(forKey: "widget_totalMes")        ?? 0
        let mes          = ud?.string(forKey: "widget_nombreMes")        ?? Date().formatted(.dateTime.month(.wide)).capitalized
        let count        = ud?.integer(forKey: "widget_cantidadCompras") ?? 0

        // Leer el código de moneda del UserDefaults estándar (preferencia del usuario)
        let currencyCode = UserDefaults.standard.string(forKey: "app_currencyCode") ?? "ARS"

        // Formatear el total como moneda según el código seleccionado por el usuario
        let totalStr   = total.formatted(.currency(code: currencyCode))
        // Pluralizar "compra/compras" según la cantidad
        let comprasStr = "\(count) compra\(count == 1 ? "" : "s")"
        // Texto que Siri leerá en voz alta
        let dialog     = IntentDialog(stringLiteral: "Este mes gastaste \(totalStr) en \(comprasStr). (\(mes))")

        // Retornar resultado con diálogo + vista visual embebida
        return .result(dialog: dialog) {
            GastosMesSnippet(total: total, mes: mes, cantidad: count, currencyCode: currencyCode)
        }
    }
}

// MARK: - Vista Snippet de Siri

import SwiftUI

/// Vista SwiftUI mostrada en la interfaz de Siri al ejecutar `GastosMesIntent`.
///
/// Siri embebe esta vista dentro de su propia UI al mostrar la respuesta.
/// El diseño es compacto para adaptarse al espacio limitado de la UI de Siri.
///
/// Equivalente Android: un `Slice` de Android que permite a las apps mostrar
/// fragmentos de su UI dentro de Google Search, Assistant, etc.
struct GastosMesSnippet: View {
    /// Total gastado en el mes, en la moneda del usuario.
    let total: Double

    /// Nombre del mes en texto (ej: "Mayo 2026").
    let mes: String

    /// Cantidad de compras realizadas en el mes.
    let cantidad: Int

    /// Código ISO 4217 de la moneda (ej: "ARS", "USD", "EUR").
    var currencyCode: String = "ARS"

    var body: some View {
        HStack(spacing: 14) {
            // Ícono de la app con gradiente verde
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.290, green: 0.867, blue: 0.502),
                                     Color(red: 0.086, green: 0.639, blue: 0.290)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "cart.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)

            // Datos del mes: nombre, total y cantidad de compras
            VStack(alignment: .leading, spacing: 2) {
                // Mes con formato capitalizado (ej: "Mayo 2026")
                Text(mes.capitalized)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                // Total formateado como moneda — minimumScaleFactor para números largos
                Text(total.formatted(.currency(code: currencyCode)))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.6)   // Reduce el tamaño de fuente si no cabe en 1 línea
                    .lineLimit(1)

                // Cantidad de compras con plural correcto
                Text("\(cantidad) compra\(cantidad == 1 ? "" : "s")")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }
}

// MARK: - Proveedor de Atajos de Siri

/// Registra los atajos de voz de la app para que aparezcan en Siri y en la app Atajos.
///
/// `AppShortcutsProvider` declara qué intents tienen frases de voz predefinidas.
/// El sistema registra estas frases automáticamente — el usuario no necesita
/// configurar nada en la app Atajos para usarlas.
///
/// Las frases usan `\(.applicationName)` para incluir el nombre de la app
/// dinámicamente, garantizando que Siri identifique el contexto correcto incluso
/// si el usuario tiene múltiples apps similares instaladas.
///
/// Equivalente Android: las `App Actions` registradas en `shortcuts.xml` con
/// `<intent android:action="...">` y `<capability>` de Google Assistant.
struct SuperAhorroShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GastosMesIntent(),
            // Frases que activan este atajo — Siri las reconoce en español
            phrases: [
                "¿Cuánto gasté este mes en \(.applicationName)?",
                "Cuánto gasté en \(.applicationName)",
                "Mis gastos de este mes en \(.applicationName)",
                "Gasto del mes en \(.applicationName)",
                "¿Cuánto llevo gastado en \(.applicationName)?"
            ],
            shortTitle: "Gasto del mes",    // Nombre corto en la app Atajos
            systemImageName: "cart.fill"    // Ícono del atajo
        )
    }
}
