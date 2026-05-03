import AppIntents
import Foundation

// MARK: - Intent

struct GastosMesIntent: AppIntent {
    static var title: LocalizedStringResource = "Gasto del mes"
    static var description = IntentDescription(
        "Consulta cuánto gastaste este mes en el supermercado.",
        categoryName: "Consultas"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let ud           = UserDefaults(suiteName: "group.com.undef.superahorro")
        let total        = ud?.double(forKey: "widget_totalMes")        ?? 0
        let mes          = ud?.string(forKey: "widget_nombreMes")        ?? Date().formatted(.dateTime.month(.wide)).capitalized
        let count        = ud?.integer(forKey: "widget_cantidadCompras") ?? 0
        let currencyCode = UserDefaults.standard.string(forKey: "app_currencyCode") ?? "ARS"

        let totalStr   = total.formatted(.currency(code: currencyCode))
        let comprasStr = "\(count) compra\(count == 1 ? "" : "s")"
        let dialog     = IntentDialog(stringLiteral: "Este mes gastaste \(totalStr) en \(comprasStr). (\(mes))")

        return .result(dialog: dialog) {
            GastosMesSnippet(total: total, mes: mes, cantidad: count, currencyCode: currencyCode)
        }
    }
}

// MARK: - Snippet View

import SwiftUI

struct GastosMesSnippet: View {
    let total: Double
    let mes: String
    let cantidad: Int
    var currencyCode: String = "ARS"

    var body: some View {
        HStack(spacing: 14) {
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

            VStack(alignment: .leading, spacing: 2) {
                Text(mes.capitalized)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(total.formatted(.currency(code: currencyCode)))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("\(cantidad) compra\(cantidad == 1 ? "" : "s")")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }
}

// MARK: - Shortcuts Provider

struct SuperAhorroShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GastosMesIntent(),
            phrases: [
                "¿Cuánto gasté este mes en \(.applicationName)?",
                "Cuánto gasté en \(.applicationName)",
                "Mis gastos de este mes en \(.applicationName)",
                "Gasto del mes en \(.applicationName)",
                "¿Cuánto llevo gastado en \(.applicationName)?"
            ],
            shortTitle: "Gasto del mes",
            systemImageName: "cart.fill"
        )
    }

}
