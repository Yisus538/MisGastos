# CLAUDE.md — Súper Ahorro iOS
> Fuente de verdad del proyecto. Actualizá este archivo al final de cada ciclo de implementación.
> Última actualización: 2026-04-29 (ciclo: exportación CSV/PDF + ActivitySheet + botón en HistorialView)

---

## Contexto del proyecto

**App**: Súper Ahorro (iOS)
**Objetivo**: App para registrar, consultar y analizar gastos de supermercado.
**Xcode project**: `MisGastos.xcodeproj` (nombre interno del proyecto Xcode)
**Bundle**: app "Súper Ahorro" — Bundle ID: `com.undef.superahorro.MartinezBulatovich`
**Git**: versionado local (rama `main`)
**Enunciado**: `Enunciado_iOS_Integrador_2026.pdf` en la carpeta raíz del TP.

---

## Estructura de carpetas

```
MisGastos/
├── CLAUDE.md                          ← este archivo
├── MisGastos.xcodeproj/
└── MisGastos/
    ├── MisGastosApp.swift             ← entry point, modelContainer setup
    ├── ContentView.swift
    ├── Models/
    │   ├── Compra.swift
    │   ├── Producto.swift
    │   └── Usuario.swift
    ├── ViewModels/
    │   ├── AuthViewModel.swift
    │   └── ComprasViewModel.swift
    ├── Views/
    │   ├── Auth/
    │   │   ├── SplashView.swift
    │   │   ├── LoginView.swift
    │   │   ├── RegisterView.swift
    │   │   └── ForgotPasswordView.swift ← extraído de RegisterView.swift, flujo completo
    │   ├── Compras/
    │   │   ├── HomeView.swift
    │   │   ├── HistorialView.swift
    │   │   ├── NuevaCompraView.swift  ← incluye StorePickerSheet, PaymentPickerSheet
    │   │   ├── DetalleCompraView.swift
    │   │   └── EditarCompraView.swift ← edición de compra existente
    │   ├── Estadisticas/
    │   │   └── EstadisticasView.swift
    │   ├── Navigation/
    │   │   └── MainTabView.swift
    │   ├── Perfil/
    │   │   ├── PerfilView.swift
    │   │   ├── EditarPerfilView.swift
    │   │   └── SettingsView.swift     ← incluye NotificationService (pendiente extraer a Services/)
    │   └── Productos/
    │       ├── NuevoProductoView.swift    ← incluye ProductoRowView, scanner código de barras
    │       └── EditarProductoView.swift   ← edición de producto existente, scanner código de barras
    ├── Services/
    │   └── NetworkService.swift
    ├── Utils/
    │   ├── DesignSystem.swift
    │   └── BarcodeScannerView.swift ← AVFoundation + UIViewControllerRepresentable, vibración al escanear
    └── Resources/
        └── Localizable.xcstrings
```

---

## Convenciones de nombres

| Ámbito | Convención | Ejemplo |
|--------|-----------|---------|
| Componentes UI compartidos | Prefijo `SA` | `SACard`, `SAField`, `SAButton`, `SABrandMark`, `SAStoreAvatar` |
| ViewModels | Sufijo `ViewModel` | `AuthViewModel`, `ComprasViewModel` |
| Views | Sufijo `View` | `HomeView`, `NuevaCompraView` |
| Sheets internas | Sufijo `Sheet` | `StorePickerSheet`, `PaymentPickerSheet` |
| Models | PascalCase sin sufijo | `Compra`, `Producto`, `Usuario` |
| Services | Sufijo `Service` | `NetworkService`, `NotificationService` |
| Tokens de color | Prefijo `sa` (extensión Color) | `Color.saGreen`, `Color.saBg`, `Color.saCard` |
| Localization keys | `entidad.campo` o `action.x` | `"producto.nombre"`, `"action.cancel"` |
| Arrays constantes | Prefijo `sa` + plural | `saSupermercados`, `saMetodosPago` |

---

## SwiftData Models y relaciones

### `Compra` — `Models/Compra.swift`
```swift
@Model final class Compra {
    var id: UUID
    var fecha: Date
    var supermercado: String
    var total: Double
    var metodoPago: String = "Efectivo"
    var imagenTicket: Data?
    @Relationship(deleteRule: .cascade) var productos: [Producto]
}
```
- Relación **uno-a-muchos** con `Producto` (cascade delete)
- `total` se actualiza manualmente al agregar/editar productos

### `Producto` — `Models/Producto.swift`
```swift
@Model final class Producto {
    var id: UUID
    var codigo: String
    var nombre: String
    var descripcion: String
    var precio: Double
    var compra: Compra?
}
```
- Relación inversa con `Compra` (opcional)

### `Usuario` — `Models/Usuario.swift`
```swift
@Model final class Usuario {
    var id: UUID
    var nombre: String
    var email: String       // normalizado a lowercase
    var password: String    // plain text (TP)
    var telefono: String
    var avatarData: Data?
}
```
- Registro: crea `Usuario` en SwiftData, valida email único, contraseña mínimo 6 caracteres
- Login: busca `Usuario` por email (FetchDescriptor + #Predicate), compara password
- Sesión activa persiste en `@AppStorage` (isLoggedIn, usuarioEmail, usuarioNombre)

### modelContainer (MisGastosApp.swift)
```swift
.modelContainer(for: [Compra.self, Producto.self, Usuario.self])
```

---

## ViewModels registrados

| ViewModel | Patrón | Responsabilidad |
|-----------|--------|----------------|
| `AuthViewModel` | `@Observable` | Estado de login/registro. Persiste sesión con `UserDefaults` (no `@AppStorage` — los VMs no importan SwiftUI). |
| `ComprasViewModel` | `@Observable` | Carga lista de supermercados desde API. |

**Patrón de instanciación**: `@State private var viewModel = AuthViewModel()` directamente en la View, sin `@StateObject`. Se usa `@Observable` de Swift 5.9, no `ObservableObject`.

**Imports en ViewModels**: `import Foundation` + `import Observation` + `import SwiftData`. Nunca `import SwiftUI` en ViewModels — usar `UserDefaults` en lugar de `@AppStorage`.

---

## DesignSystem — `Utils/DesignSystem.swift`

### Tokens de color disponibles
`Color.saGreen`, `Color.saGreenDark`, `Color.saGreenLight`, `Color.saGreenBg`,
`Color.saBg`, `Color.saCard`, `Color.saLabel`, `Color.saLabel2`, `Color.saLabel3`,
`Color.saLabel4`, `Color.saSep`, `Color.saDanger`

### Gradientes
`LinearGradient.saGreen` — verde brand diagonal

### Componentes reutilizables
- `SABrandMark(size:)` — logo de la app
- `SAStoreAvatar(name:size:)` — avatar de supermercado con color por cadena
- `SACard<Content>` — card con sombra y rounding
- `SAField` — campo de texto estilizado con ícono opcional y toggle de contraseña
- `SAButton` — botón primario o destructivo con estado loading
- `MGInputField`, `MGButton` — wrappers legacy (no usar en código nuevo)

### Datos constantes
- `saSupermercados: [String]` — 8 cadenas hardcodeadas
- `saMetodosPago: [String]` — 5 métodos
- `saStoreInfo(for:) -> SAStoreInfo` — color + iniciales por cadena

---

## Servicios

### `ExportService` — `Services/ExportService.swift`
- Singleton: `ExportService.shared`
- `generarCSV(compras: [Compra]) -> URL?` — escribe en `FileManager.temporaryDirectory`, BOM UTF-8 para Excel. Secciones: RESUMEN + COMPRAS + PRODUCTOS
- `generarPDF(compras: [Compra]) -> URL?` — `UIGraphicsPDFRenderer` A4, header verde, card de resumen (total gastado / nº compras / nº productos), filas agrupadas por mes, paginación automática
- Extensión privada `String.csvEscaped` para comillas y comas

### `ActivitySheet` — `Utils/ActivitySheet.swift`
- `UIViewControllerRepresentable` que presenta `UIActivityViewController`
- Fix de iPad: asigna `popoverPresentationController.sourceView` al center de la pantalla para evitar crash

### `TicketOCRService` — `Services/TicketOCRService.swift`
- Singleton: `TicketOCRService.shared`
- `extraerProductos(de: Data) async -> [ProductoDraft]` — Vision `VNRecognizeTextRequest` (.accurate), parsea líneas buscando nombre + precio
- Formato soportado: `$189.99`, `189,99`, `$1.234,56` (formato ARS)
- Líneas de total/iva/descuento/tarjeta se filtran automáticamente
- Formato dos líneas (nombre en una, precio en la siguiente) también soportado

### `ProductoDraft` — definido en `TicketOCRService.swift`
```swift
struct ProductoDraft: Identifiable, Equatable {
    var id = UUID()
    var nombre: String
    var descripcion: String = ""
    var codigo: String = ""
    var precio: Double
}
```
- Modelo borrador local, usado en `NuevaCompraView` antes de persistir en SwiftData

### `NetworkService` — `Services/NetworkService.swift`
- Singleton: `NetworkService.shared`
- `fetchSupermercados() async throws -> [String]` — actualmente usa `https://jsonplaceholder.typicode.com/users`; mapea company.name. Fallback: `supermercadosFallback`
- Patrón: URLSession + async/await

### `BiometricService` — `Services/BiometricService.swift`
- Singleton: `BiometricService.shared`
- `biometricType` — detecta `.faceID`, `.touchID` o `.none` via `LAContext`
- `isAvailable: Bool` — convenience property
- `authenticate(reason:) async -> Bool` — llama `evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)`
- Usado en `LoginView`: botón "Continuar con Face ID/Touch ID" visible cuando hay `usuarioEmail` guardado

### `NotificationService` — actualmente embebido en `SettingsView.swift`
- Pendiente extracción a `Services/NotificationService.swift`
- `solicitarPermiso() async -> Bool`
- `programarRecordatorio(diaSemana:hora:)` — UNCalendarNotificationTrigger semanal

---

| Comparativa de precios | `Views/Compras/ComparativaView.swift` | Tab propio. Agrupa productos por nombre entre compras, muestra precio por supermercado (más barato ✅ / más caro 🔴), badge de ahorro, `ContentUnavailableView` cuando no hay datos |

## Features implementadas ✅

| Feature | Archivo/s clave | Notas |
|---------|----------------|-------|
| Splash animado | `SplashView.swift` | Spring + fade, 2.2s, redirige a Login o MainTabView |
| Login | `LoginView.swift`, `AuthViewModel.swift` | @AppStorage. Social buttons (Apple/Google) son decorativos |
| Registro | `RegisterView.swift`, `AuthViewModel.swift` | |
| Recuperar contraseña | `ForgotPasswordView.swift` | 2 estados: form (email + validación) → success (confirmación + opción "no recibí"). Loading 1.2s simulado. |
| Logout | `PerfilView.swift`, `SettingsView.swift` | `isLoggedIn = false` |
| Perfil de usuario | `PerfilView.swift`, `EditarPerfilView.swift` | Datos en @AppStorage |
| Settings (dark mode, notificaciones) | `SettingsView.swift` | Dark mode via @AppStorage("isDarkMode") |
| Home con resumen mensual | `HomeView.swift` | Compras este mes, delta vs mes anterior, promedio, tiendas |
| Crear compra | `NuevaCompraView.swift` | Flujo rediseñado: se deben agregar productos antes de guardar. Total se calcula automáticamente. OCR de ticket con `TicketOCRService` (Vision), detecta productos y filtra duplicados. `AgregarProductoSheet` para agregar productos inline. |
| Editar compra existente | `EditarCompraView.swift` | Modal sheet desde DetalleCompraView (botón lápiz en header). Pre-popula campos. Guarda via @Bindable directo a SwiftData. |
| Eliminar compra | `DetalleCompraView.swift` | Alert de confirmación |
| Detalle de compra | `DetalleCompraView.swift` | Lista productos, ticket, compartir (ShareLink) |
| Agregar producto a compra | `NuevoProductoView.swift` | Actualiza compra.total al guardar. Scanner de código de barras (BarcodeScannerView). |
| Editar producto existente | `EditarProductoView.swift` | Sheet desde DetalleCompraView (tap en fila). Ajusta compra.total con delta de precio. Scanner de código de barras. |
| Eliminar producto | `DetalleCompraView.swift` | Context menu (long press en fila). Resta precio de compra.total. |
| Historial de compras | `HistorialView.swift` | |
| Estadísticas Swift Charts | `EstadisticasView.swift` | BarMark, LineMark+AreaMark, SectorMark (donut por tienda), productos más comprados. Rango 3m/6m/1a, comparación mes anterior, insights |
| Persistencia SwiftData | `MisGastosApp.swift` | modelContainer con Compra, Producto, Usuario |
| Networking URLSession/async-await | `NetworkService.swift` | |
| Notificaciones locales | `SettingsView.swift` | UNUserNotificationCenter, recordatorio semanal |
| Internacionalización | `Localizable.xcstrings` | Claves en formulario de producto, acciones |
| DesignSystem | `DesignSystem.swift` | Tokens de color, gradientes, componentes SA* |
| Navegación por tabs | `MainTabView.swift` | TabView con 5 tabs, NavigationStack por tab |

---

## Features pendientes ⬜

### Segunda Entrega (urgente)
| Feature | Estado | Archivos a crear/modificar |
|---------|--------|--------------------------|
| ~~ForgotPasswordView~~ | ✅ Implementado | `Views/Auth/ForgotPasswordView.swift` |
| ~~Editar compra existente~~ | ✅ Implementado | `Views/Compras/EditarCompraView.swift` |
| ~~Editar/eliminar producto dentro de compra~~ | ✅ Implementado | `EditarProductoView.swift` + context menu en `DetalleCompraView.swift` |
| ~~Scanner de código de barras~~ | ✅ Implementado | `Utils/BarcodeScannerView.swift` en NuevoProductoView y EditarProductoView |
| ~~Captura desde cámara (no solo galería)~~ | ✅ Implementado | `Utils/CameraPickerView.swift` (UIImagePickerController + UIViewControllerRepresentable). `confirmationDialog` "Cámara / Galería" en `NuevaCompraView` y `DetalleCompraView`. |
| ~~ViewModels sin import SwiftUI~~ | ✅ Implementado | `AuthViewModel` usa `UserDefaults`, `ComprasViewModel` usa `import Observation` |
| ~~ContentUnavailableView en listas~~ | ✅ Implementado | `HomeView`, `HistorialView`, `ComparativaView` |
| Persistencia perfil con SwiftData | ⬜ Falta | Sincronizar @AppStorage con modelo `Usuario` |
| Extracción NotificationService | ⬜ Deuda técnica | Mover de SettingsView a `Services/NotificationService.swift` |
| API real de supermercados | ⬜ Mejora | Reemplazar JSONPlaceholder en NetworkService |

### Etapa Final (extras)
| Feature | Estado |
|---------|--------|
| ~~OCR de tickets (Vision framework)~~ | ✅ Implementado | `Services/TicketOCRService.swift` — VNRecognizeTextRequest, integrado en `NuevaCompraView` al adjuntar ticket |
| Sincronización iCloud (CloudKit) | ⬜ Falta |
| Face ID / Touch ID (LocalAuthentication) | ⬜ Falta |
| Deep links / navegación programática avanzada | ⬜ Falta |

---

## Decisiones de arquitectura

1. **SwiftData** en vez de CoreData o SQLite — decisión tomada desde el inicio. No revertir.
2. **`@Observable`** (Swift 5.9) en vez de `ObservableObject` — más simple, no requiere `@Published`. ViewModels se instancian con `@State` en la View, no con `@StateObject`.
3. **`@AppStorage`** para la sesión activa (isLoggedIn, usuarioEmail, usuarioNombre, isDarkMode). El modelo `Usuario` en SwiftData es paralelo y aún no se sincroniza con @AppStorage.
4. **Custom DesignSystem** centralizado en `DesignSystem.swift`. Todos los tokens de color son adaptativos (UIColor con closure para dark/light mode). Nunca hardcodear colores en Views.
5. **NavigationStack** por tab (no global). Cada tab tiene su propio stack.
6. **Prefijo `SA`** para todos los componentes compartidos del DesignSystem.
7. **Lógica en ViewModels**, cero lógica de negocio en Views. Las Views solo llaman métodos del ViewModel.
8. **`Localizable.xcstrings`** (formato moderno de Xcode 15+), no `.strings`. Usar `String(localized:)` o `.localized` en SwiftUI Text.

---

## MCP de Notion

El MCP de Notion está configurado y disponible. Usarlo para:
- Leer los requerimientos del TP y chequear ítems pendientes
- Marcar features como completadas (✅) al cerrar cada ciclo
- Agregar nuevos ítems si se implementa algo no documentado

---

## Pipeline multi-agente

Este proyecto usa un flujo de 3 agentes que se invocan via slash commands:

| Comando | Agente | Rol |
|---------|--------|-----|
| `/agente1` | Arquitecto/Desarrollador | Decide qué implementar, escribe código SwiftUI/SwiftData |
| `/agente2` | Revisor de Calidad | Revisa el output del Agente 1 contra este CLAUDE.md |
| `/agente3` | Tester | Genera tests una vez que Agente 2 aprueba |
| `/ciclo-cierre` | Cierre | Actualiza CLAUDE.md + Notion al finalizar el ciclo |

**Regla de oro**: ningún ciclo está completo sin actualizar este CLAUDE.md y el Notion del TP.

**El hook `Stop`** del proyecto verifica que CLAUDE.md fue actualizado cuando se modificaron archivos .swift. Si no lo fue, bloquea el stop con un recordatorio.
