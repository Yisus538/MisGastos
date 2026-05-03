import WidgetKit
import SwiftUI

// MARK: - Shared keys (deben coincidir con WidgetDataWriter en el target principal)

private enum SK {
    static let suite            = "group.com.undef.superahorro"
    static let totalMes         = "widget_totalMes"
    static let nombreMes        = "widget_nombreMes"
    static let cantidadCompras  = "widget_cantidadCompras"
    static let presupuesto      = "widget_presupuesto"
    static let presupuestoActivo = "widget_presupuestoActivo"
}

// MARK: - Entry

struct GastosMesEntry: TimelineEntry {
    let date: Date
    let totalMes: Double
    let nombreMes: String
    let cantidadCompras: Int
    let presupuesto: Double
    let presupuestoActivo: Bool

    static let placeholder = GastosMesEntry(
        date: .now,
        totalMes: 47_500,
        nombreMes: "Mayo",
        cantidadCompras: 4,
        presupuesto: 100_000,
        presupuestoActivo: true
    )
}

// MARK: - Provider

struct GastosProvider: TimelineProvider {
    func placeholder(in context: Context) -> GastosMesEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (GastosMesEntry) -> Void) {
        completion(context.isPreview ? .placeholder : readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GastosMesEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        completion(Timeline(entries: [readEntry()], policy: .after(next)))
    }

    private func readEntry() -> GastosMesEntry {
        let ud = UserDefaults(suiteName: SK.suite)
        return GastosMesEntry(
            date: .now,
            totalMes:        ud?.double(forKey: SK.totalMes) ?? 0,
            nombreMes:       ud?.string(forKey: SK.nombreMes) ?? Date().formatted(.dateTime.month(.wide)).capitalized,
            cantidadCompras: ud?.integer(forKey: SK.cantidadCompras) ?? 0,
            presupuesto:     ud?.double(forKey: SK.presupuesto) ?? 0,
            presupuestoActivo: ud?.bool(forKey: SK.presupuestoActivo) ?? false
        )
    }
}

// MARK: - Views

struct MisGastosWidgetView: View {
    let entry: GastosMesEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium:           mediumView
        case .accessoryRectangular:   lockScreenView
        default:                      smallView
        }
    }

    // MARK: Small

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandRow
            Spacer()
            Text(entry.nombreMes.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .tracking(0.4)
            Text(entry.totalMes.formatted(.currency(code: "ARS")))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .tracking(-0.5)
                .padding(.top, 2)
            Text("\(entry.cantidadCompras) compra\(entry.cantidadCompras == 1 ? "" : "s")")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.top, 4)
            if entry.presupuestoActivo && entry.presupuesto > 0 {
                budgetBar(pct: min(entry.totalMes / entry.presupuesto, 1))
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }

    // MARK: Medium

    private var mediumView: some View {
        HStack(spacing: 0) {
            // Left
            VStack(alignment: .leading, spacing: 0) {
                brandRow
                Spacer()
                Text("TOTAL DEL MES")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.70))
                    .tracking(0.3)
                Text(entry.nombreMes.capitalized)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.90))
                    .padding(.top, 2)
            }
            .frame(maxHeight: .infinity, alignment: .leading)
            .padding(.leading, 16)
            .padding(.vertical, 14)

            // Divider
            Rectangle()
                .fill(.white.opacity(0.22))
                .frame(width: 1)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)

            // Right
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                Text(entry.totalMes.formatted(.currency(code: "ARS")))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .tracking(-0.5)
                Text("\(entry.cantidadCompras) compra\(entry.cantidadCompras == 1 ? "" : "s") este mes")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 3)
                if entry.presupuestoActivo && entry.presupuesto > 0 {
                    let pct = min(entry.totalMes / entry.presupuesto, 1)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Presupuesto")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.70))
                            Spacer()
                            Text(String(format: "%.0f%%", pct * 100))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        budgetBar(pct: pct)
                    }
                    .padding(.top, 8)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.trailing, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: Lock Screen

    private var lockScreenView: some View {
        HStack(spacing: 8) {
            Image(systemName: "cart.fill")
                .font(.system(size: 13, weight: .bold))
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.nombreMes.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .opacity(0.75)
                    .tracking(0.3)
                Text(entry.totalMes.formatted(.currency(code: "ARS")))
                    .font(.system(size: 14, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            Spacer()
            if entry.presupuestoActivo && entry.presupuesto > 0 {
                Text(String(format: "%.0f%%", min(entry.totalMes / entry.presupuesto, 1) * 100))
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    // MARK: Shared subviews

    private var brandRow: some View {
        HStack(spacing: 5) {
            Image(systemName: "cart.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.80))
            Text("SÚPER AHORRO")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.80))
                .tracking(0.4)
            Spacer()
        }
    }

    @ViewBuilder
    private func budgetBar(pct: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.25))
                    .frame(height: 4)
                Capsule()
                    .fill(.white)
                    .frame(width: max(geo.size.width * pct, 4), height: 4)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Widget

struct MisGastosWidget: Widget {
    let kind = "MisGastosWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GastosProvider()) { entry in
            MisGastosWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.290, green: 0.867, blue: 0.502), location: 0),
                            .init(color: Color(red: 0.133, green: 0.773, blue: 0.369), location: 0.55),
                            .init(color: Color(red: 0.086, green: 0.639, blue: 0.290), location: 1),
                        ],
                        startPoint: UnitPoint(x: 0.2, y: 0),
                        endPoint: UnitPoint(x: 0.8, y: 1)
                    )
                }
        }
        .configurationDisplayName("Súper Ahorro")
        .description("Total gastado en el mes actual.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Bundle

@main
struct MisGastosWidgetBundle: WidgetBundle {
    var body: some Widget {
        MisGastosWidget()
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    MisGastosWidget()
} timeline: {
    GastosMesEntry.placeholder
}

#Preview(as: .systemMedium) {
    MisGastosWidget()
} timeline: {
    GastosMesEntry.placeholder
}

#Preview(as: .accessoryRectangular) {
    MisGastosWidget()
} timeline: {
    GastosMesEntry.placeholder
}
