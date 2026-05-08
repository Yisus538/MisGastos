// =============================================================================
// ComprasViewModel.swift — ViewModel para datos de referencia de compras
// =============================================================================
// Rol en la app:
//   Carga y cachea la lista de supermercados disponibles para seleccionar
//   al crear una nueva compra. Delega la obtención de datos a `NetworkService`,
//   que implementa una estrategia en cascada: Supabase → cache local → hardcoded.
//
// Equivalente Android:
//   ViewModel + StateFlow. En Android se haría con `viewModelScope.launch { }`
//   y `MutableStateFlow<List<String>>` para la lista de supermercados.
//   `NetworkService` sería el equivalente a un Repositorio con Retrofit/OkHttp.
//
// Patrón @Observable:
//   Equivalente a `@HiltViewModel` + `StateFlow` en Android con Hilt DI.
//   Aquí no hay inyección de dependencias formal — se usa el singleton de
//   `NetworkService.shared` directamente (patrón más simple para un TP).
// =============================================================================

import Foundation
import Observation

/// ViewModel que carga y cachea la lista de supermercados desde la red.
///
/// Provee los datos que necesita `NuevaCompraView` para el selector de tiendas.
/// Equivalente Android: `ViewModel` con `viewModelScope.launch { }` y Retrofit.
@Observable
final class ComprasViewModel {

    // MARK: - Estado observable

    /// Lista de supermercados disponibles para seleccionar.
    /// Las vistas se actualizan automáticamente cuando esta propiedad cambia.
    var supermercados: [String] = []

    /// Indica si hay una carga de datos en progreso (para mostrar un spinner).
    var isLoading: Bool = false

    /// Mensaje de error si la carga falla (nil = sin error).
    var errorMessage: String?

    // MARK: - Carga de datos

    /// Obtiene la lista de supermercados con estrategia de fallback en cascada.
    ///
    /// Orden de prioridad (definido en `NetworkService`):
    /// 1. Supabase (tabla `supermercados`) — fuente de verdad remota.
    /// 2. Caché en `UserDefaults` — funciona sin conexión.
    /// 3. Lista hardcodeada en el código — siempre disponible.
    ///
    /// Este patrón es equivalente a un repositorio con `NetworkBoundResource` en Android:
    /// primero intenta datos frescos de la red, luego cae al caché local.
    ///
    /// `async/await` → en Android sería `viewModelScope.launch { withContext(Dispatchers.IO) { } }`
    func cargarSupermercados() async {
        isLoading = true
        defer { isLoading = false }
        do {
            supermercados = try await NetworkService.shared.fetchSupermercados()
        } catch {
            // Si falla la red y el caché, usar la lista hardcodeada como último recurso
            errorMessage = "No se pudo cargar la lista de tiendas."
            supermercados = NetworkService.shared.supermercadosFallback
        }
    }
}
