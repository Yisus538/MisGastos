// =============================================================================
// WidgetDataWriter.swift — Escritura de datos hacia el Widget de iOS
// =============================================================================
// Rol en la app:
//   Escribe los datos del gasto mensual en un `UserDefaults` compartido entre
//   la app principal y la extensión del Widget. Después de escribir, notifica
//   al sistema que los Widgets deben actualizarse con los nuevos datos.
//   Se llama desde `HomeView` cada vez que cambian las compras del mes.
//
// Equivalente Android:
//   En Android, los Widgets se actualizan via `AppWidgetManager.updateAppWidget()`
//   + `RemoteViews`. Para compartir datos entre la app y el widget se usa un
//   `ContentProvider` o un archivo compartido. En Compose/Glance:
//   `GlanceAppWidgetManager(context).requestPinGlanceAppWidget(...)`.
//
// App Groups (Grupos de App):
//   Los procesos de iOS están completamente aislados por sandboxing. Una app y su
//   extensión de Widget son procesos separados que NO pueden acceder al UserDefaults
//   estándar el uno del otro. La solución son los **App Groups**: una capacidad de
//   Xcode que crea un contenedor de UserDefaults compartido, accesible por la app
//   principal y todas sus extensiones via `UserDefaults(suiteName: "group.xxx")`.
//
//   Para que funcione:
//   1. Activar "App Groups" en las Capabilities del target app principal.
//   2. Activar "App Groups" en las Capabilities del target widget.
//   3. Usar el mismo group ID en ambos.
//
//   Equivalente Android: el mecanismo de `ContentProvider` con `android:exported=true`
//   para compartir datos entre una app y su App Widget provider.
//
// WidgetKit:
//   `WidgetCenter.shared.reloadAllTimelines()` le dice a iOS que invalide todos
//   los Widgets de la app y los redibuje con datos frescos. El Widget tiene su
//   propia `TimelineProvider` que lee los datos del App Group UserDefaults.
// =============================================================================

import Foundation
import WidgetKit

/// Namespace de funciones para escribir datos hacia el Widget de Súper Ahorro.
///
/// Se implementa como `enum` sin casos (en lugar de `struct` o `class`) para
/// crear un namespace puro — no se puede instanciar, solo llamar a sus `static func`.
/// Equivalente Android: un `object` de Kotlin (singleton) o una clase con solo
/// métodos estáticos.
enum WidgetDataWriter {

    // MARK: - App Group ID

    /// Identificador del App Group compartido entre la app y el Widget.
    ///
    /// Debe coincidir exactamente con el group registrado en Xcode Capabilities
    /// para que el UserDefaults sea accesible por ambos procesos.
    private static let suite = "group.com.undef.superahorro"

    // MARK: - Escritura de datos

    /// Escribe los datos del mes actual en el App Group y actualiza los Widgets.
    ///
    /// El Widget lee estas claves desde su `TimelineProvider` para mostrar
    /// el gasto mensual, la barra de progreso del presupuesto y la cantidad de compras.
    ///
    /// El call a `WidgetCenter.shared.reloadAllTimelines()` es fundamental:
    /// sin él, el Widget seguiría mostrando datos del timeline anterior hasta que
    /// iOS decida actualizar por su cuenta (lo que puede tardar horas).
    ///
    /// Equivalente Android: `AppWidgetManager.getInstance(context).updateAppWidget(id, views)`
    /// donde `views` es un `RemoteViews` con los datos actualizados.
    ///
    /// - Parameters:
    ///   - totalMes: Suma de todas las compras del mes actual en la moneda local.
    ///   - nombreMes: Nombre del mes en español (ej: "Mayo 2026").
    ///   - cantidadCompras: Número de compras realizadas en el mes.
    ///   - presupuesto: Límite de presupuesto mensual definido por el usuario (0 si no hay).
    ///   - presupuestoActivo: `true` si el usuario tiene un presupuesto configurado.
    static func write(
        totalMes: Double,
        nombreMes: String,
        cantidadCompras: Int,
        presupuesto: Double = 0,
        presupuestoActivo: Bool = false
    ) {
        // `UserDefaults(suiteName:)` accede al contenedor compartido del App Group.
        // Si falla (group no configurado en Xcode), guarda en nil y se sale silenciosamente.
        guard let ud = UserDefaults(suiteName: suite) else { return }

        // Escribir todos los datos con claves predefinidas
        ud.set(totalMes,          forKey: "widget_totalMes")
        ud.set(nombreMes,         forKey: "widget_nombreMes")
        ud.set(cantidadCompras,   forKey: "widget_cantidadCompras")
        ud.set(presupuesto,       forKey: "widget_presupuesto")
        ud.set(presupuestoActivo, forKey: "widget_presupuestoActivo")

        // Notificar a WidgetKit que debe recargar los timelines de todos los Widgets.
        // Esto dispara una nueva llamada a `TimelineProvider.getTimeline()` en el Widget,
        // que leerá las claves recién escritas del App Group.
        WidgetCenter.shared.reloadAllTimelines()
    }
}
