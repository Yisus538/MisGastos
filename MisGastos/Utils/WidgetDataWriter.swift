import Foundation
import WidgetKit

enum WidgetDataWriter {
    private static let suite = "group.com.undef.superahorro"

    static func write(
        totalMes: Double,
        nombreMes: String,
        cantidadCompras: Int,
        presupuesto: Double = 0,
        presupuestoActivo: Bool = false
    ) {
        guard let ud = UserDefaults(suiteName: suite) else { return }
        ud.set(totalMes,         forKey: "widget_totalMes")
        ud.set(nombreMes,        forKey: "widget_nombreMes")
        ud.set(cantidadCompras,  forKey: "widget_cantidadCompras")
        ud.set(presupuesto,      forKey: "widget_presupuesto")
        ud.set(presupuestoActivo, forKey: "widget_presupuestoActivo")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
