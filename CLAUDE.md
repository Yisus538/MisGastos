# CLAUDE.md — Súper Ahorro iOS
> Fuente de verdad del proyecto. Actualizá este archivo al final de cada ciclo de implementación.
> Última actualización: 2026-05-03 (ciclo: Revisión completa — bugs ticket/Supabase, localización errores, consolidación Notion)

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
    │   ├── Compra.swift               ← +ticketURL: String? (Supabase Storage URL)
    │   ├── Producto.swift
    │   └── Usuario.swift              ← deprecated (solo compat); auth ahora en Supabase
    ├── ViewModels/
    │   ├── AuthViewModel.swift        ← usa SupabaseService (sin SwiftData/ModelContext)
    │   ├── ComprasViewModel.swift
    │   └── SessionStore.swift         ← NUEVO: singleton @Observable @MainActor; suscribe a authStateChanges de Supabase; única fuente de verdad de isAuthenticated
    ├── Views/
    │   ├── Auth/
    │   │   ├── SplashView.swift
    │   │   ├── LoginView.swift        ← sin modelContext; login via Supabase
    │   │   ├── RegisterView.swift     ← sin modelContext; registro via Supabase
    │   │   └── ForgotPasswordView.swift ← reset real via supabase.auth.resetPasswordForEmail
    │   ├── Compras/
    │   │   ├── HomeView.swift
    │   │   ├── HomeView.swift
    │   │   ├── HistorialView.swift
    │   │   ├── NuevaCompraView.swift  ← guardar() async; ticket → Supabase Storage; sync compra en background
    │   │   ├── DetalleCompraView.swift
    │   │   └── EditarCompraView.swift
    │   ├── Estadisticas/
    │   │   └── EstadisticasView.swift
    │   ├── Navigation/
    │   │   └── MainTabView.swift      ← tab Perfil muestra avatar circular del usuario (UIGraphicsImageRenderer)
    │   ├── Perfil/
    │   │   ├── PerfilView.swift       ← logout llama SupabaseService.shared.logout(); avatar desde @AppStorage("avatarData")
    │   │   ├── EditarPerfilView.swift ← PhotosPicker para cambiar foto; comprime a 300×300 JPEG; guarda en @AppStorage("avatarData")
    │   │   ├── SettingsView.swift     ← logout llama SupabaseService.shared.logout(); NotificationService definido al final del archivo
    │   │   └── AparienciaSheet.swift  ← NUEVO: sheet triestado Claro/Oscuro/Sistema; AparienciaMode enum; mockups de teléfono; guarda en Supabase (guardarApariencia)
    │   └── Productos/
    │       ├── NuevoProductoView.swift
    │       └── EditarProductoView.swift
    ├── Services/
    │   ├── SupabaseService.swift      ← singleton; auth, compras, productos, storage, supermercados, apariencia
    │   ├── NetworkService.swift       ← fetchSupermercados: Supabase → cache UserDefaults → hardcoded
    │   └── SyncService.swift          ← NUEVO: singleton @MainActor; reintenta sync de compras con isSynced=false a Supabase al arrancar
    ├── Utils/
    │   ├── DesignSystem.swift
    │   └── BarcodeScannerView.swift
    └── Resources/
        ├── Localizable.xcstrings
        └── supabase_schema.sql        ← NUEVO: SQL para ejecutar en Supabase Dashboard
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
    var ticketURL: String? = nil      // URL firmada de Supabase Storage (reemplaza imagenTicket en flujo nuevo)
    var isSynced: Bool = false        // false hasta que la compra se sincronice exitosamente a Supabase
    @Relationship(deleteRule: .cascade) var productos: [Producto]
}
```
- Relación **uno-a-muchos** con `Producto` (cascade delete)
- `total` se actualiza manualmente al agregar/editar productos
- `ticketURL`: URL firmada de Supabase Storage (1h de validez). Si el upload falla, se usa `imagenTicket` como fallback local.

### `Producto` — `Models/Producto.swift`
```swift
@Model final class Producto {
    var id: UUID
    var codigo: String
    var nombre: String
    var descripcion: String
    var precio: Double
    var isSynced: Bool = false        // false hasta que el producto se sincronice exitosamente a Supabase
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
| `AuthViewModel` | `@Observable` | Estado de login/registro. Usa `SupabaseService` para auth. Persiste sesión con `UserDefaults`. **Ya no usa `ModelContext` ni SwiftData.** |
| `ComprasViewModel` | `@Observable` | Carga lista de supermercados desde API (Supabase → cache → fallback). |
| `SessionStore` | `@Observable` + `@MainActor` | Singleton. Suscribe a `authStateChanges` de Supabase. Única fuente de verdad de `isAuthenticated`. Cachea `usuarioEmail`/`usuarioNombre` en `UserDefaults`. Instanciado en `MisGastosApp.task {}`. |

**Patrón de instanciación**: `@State private var viewModel = AuthViewModel()` directamente en la View, sin `@StateObject`. Se usa `@Observable` de Swift 5.9, no `ObservableObject`.

**Imports en ViewModels**: `import Foundation` + `import Observation`. Nunca `import SwiftUI` ni `import SwiftData` en ViewModels — usar `UserDefaults` en lugar de `@AppStorage`.

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

### `SupabaseService` — `Services/SupabaseService.swift`
- Singleton: `SupabaseService.shared`
- `client: SupabaseClient` — instancia compartida; URL y anon key en las constantes privadas
- **Auth**: `login(email:password:)`, `register(email:password:nombre:)`, `logout()`, `resetPassword(email:)`, `nombreFromMetadata() -> String?`, `isSessionActive: Bool`
- **Compras**: `fetchCompras() -> [CompraDTO]`, `crearCompra(id:fecha:supermercado:total:metodoPago:ticketURL:)`, `actualizarCompra(...)`, `borrarCompra(id:)`
- **Productos**: `crearProducto(id:compraID:nombre:descripcion:codigo:precio:)`, `actualizarProducto(...)`, `borrarProducto(id:)`
- **Storage**: `subirTicket(_ data: Data, compraID: UUID) async throws -> String` — sube a bucket `tickets-usuarios/{userID}/{compraID}.jpg`, devuelve URL firmada (1h)
- **Supermercados**: `fetchSupermercados() async throws -> [String]` — lee tabla `supermercados` de Supabase
- `SAError.noSession` — error cuando no hay sesión activa
- `CompraDTO` — struct público para transferencia de datos desde Supabase

⚠️ **Requiere**: SDK `supabase-swift` agregado en Xcode + valores `SUPABASE_URL` y `SUPABASE_ANON_KEY` en las constantes privadas.

### `NetworkService` — `Services/NetworkService.swift`
- Singleton: `NetworkService.shared`
- `fetchSupermercados() async throws -> [String]` — prioridad: Supabase tabla `supermercados` → caché UserDefaults (`cachedSupermercados`) → lista `supermercadosFallback` hardcodeada
- Ya **no** usa JSONPlaceholder

### `BiometricService` — `Services/BiometricService.swift`
- Singleton: `BiometricService.shared`
- `biometricType` — detecta `.faceID`, `.touchID` o `.none` via `LAContext`
- `isAvailable: Bool` — convenience property
- `authenticate(reason:) async -> Bool` — llama `evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)`
- Usado en `LoginView`: botón "Continuar con Face ID/Touch ID" visible cuando hay `usuarioEmail` guardado

### `NotificationService` — definido al final de `SettingsView.swift` (⬜ pendiente extracción)
- Clase `final` con singleton `shared`, definida en el mismo archivo que `SettingsView` por deuda técnica
- `solicitarPermiso() async -> Bool`
- `programarRecordatorio(diaSemana:hora:)` — UNCalendarNotificationTrigger semanal

### `SyncService` — `Services/SyncService.swift`
- Singleton: `SyncService.shared` (`@MainActor`)
- `sincronizarPendientes(context: ModelContext) async` — busca `Compra` con `isSynced == false`, las sincroniza a Supabase y marca `isSynced = true`. Llamado en `SplashView.onAppear` antes del routing.
- Seguro llamar en cada arranque: si no hay sesión activa retorna inmediatamente.

### `AparienciaMode` — `Views/Perfil/AparienciaSheet.swift`
- Enum `String` con casos `.claro`, `.oscuro`, `.sistema`
- `label: String`, `sublabel: String`, `colorScheme: ColorScheme?`
- Usado en `SplashView`, `SettingsView`, `AparienciaSheet`
- `AparienciaSheet`: presenta mockups de teléfono + lista; al seleccionar guarda en `@AppStorage("aparienciaMode")` y en Supabase (`guardarApariencia`)

---

| Comparativa de precios | `Views/Compras/ComparativaView.swift` | Tab propio. Agrupa productos por nombre entre compras, muestra precio por supermercado (más barato ✅ / más caro 🔴), badge de ahorro, `ContentUnavailableView` cuando no hay datos |
| Apariencia triestada | `Views/Perfil/AparienciaSheet.swift` | Sheet Claro/Oscuro/Sistema desde SettingsView. Mockups de teléfono. Guarda en @AppStorage("aparienciaMode") y en Supabase `perfiles.apariencia`. |
| Estado de auth Supabase | `ViewModels/SessionStore.swift` | Singleton que suscribe a `authStateChanges`. `SplashView` lo observa para routear a `MainTabView` o `LoginView` sin leer `@AppStorage` manualmente. |
| Sync offline-first | `Services/SyncService.swift` | Al arrancar la app, sincroniza compras con `isSynced=false` a Supabase. Llamado en `SplashView.onAppear`. |

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
| Persistencia SwiftData | `MisGastosApp.swift` | modelContainer con Compra, Producto, Usuario (Usuario se mantiene por compat pero ya no se crea) |
| Backend Supabase | `Services/SupabaseService.swift` | Auth bcrypt+JWT, PostgreSQL con RLS, Storage de tickets, supermercados dinámicos |
| Networking URLSession/async-await | `NetworkService.swift` | Supermercados: Supabase → cache UserDefaults → hardcoded |
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
| ~~Apariencia Claro/Oscuro/Sistema~~ | ✅ Implementado | `AparienciaSheet.swift`, reemplaza `isDarkMode` con `aparienciaMode` triestado |
| ~~Auth state via Supabase~~ | ✅ Implementado | `SessionStore.swift` — suscribe a `authStateChanges`, SplashView rutea desde aquí |
| ~~Sync offline-first~~ | ✅ Implementado | `SyncService.swift` + `isSynced` en `Compra`/`Producto` |
| Persistencia perfil con Supabase | ⬜ Falta | Leer/escribir nombre y teléfono desde tabla `perfiles` en EditarPerfilView |
| Extracción NotificationService | ⬜ Deuda técnica | Mover clase `NotificationService` de SettingsView a `Services/NotificationService.swift` |
| ~~API real de supermercados~~ | ✅ Implementado | `NetworkService` usa tabla `supermercados` de Supabase con caché |

### Etapa Final (extras)
| Feature | Estado |
|---------|--------|
| ~~OCR de tickets (Vision framework)~~ | ✅ Implementado | `Services/TicketOCRService.swift` — VNRecognizeTextRequest, integrado en `NuevaCompraView` al adjuntar ticket |
| ~~Sincronización iCloud (CloudKit)~~ | ✅ Reemplazado por Supabase (mejor para TP) |
| ~~Face ID / Touch ID (LocalAuthentication)~~ | ✅ Implementado | `BiometricService` + `LoginView`. Con Supabase: biometric valida localmente, sesión JWT persiste en Keychain. |
| ~~Sync editar/borrar compra → Supabase~~ | ✅ Implementado | `EditarCompraView.guardar()` llama `actualizarCompra` en background; `DetalleCompraView` llama `borrarCompra` al eliminar |
| ~~Sync borrar producto → Supabase~~ | ✅ Implementado | `DetalleCompraView.eliminarProducto()` llama `borrarProducto` en background |
| ~~Perfil: sincronizar con tabla `perfiles`~~ | ✅ Implementado | `EditarPerfilView`: al abrir carga `nombre` desde `perfiles` vía `fetchPerfil()`, al guardar escribe con `guardarPerfil(nombre:)`. Email deshabilitado (requiere confirmación en Supabase Auth). |
| ~~Presupuesto mensual~~ | ✅ Implementado | `SettingsView`: toggle + campo de monto. `HomeView`: card con barra de progreso verde/naranja/rojo + `.alert` disparado una vez por mes al superar el límite (`presupuestoAlertaMes` en `@AppStorage`). |
| Sign in with Apple / Google OAuth | ⬜ Próximo ciclo | Requiere configuración URL scheme en Xcode + Supabase OAuth providers |
| Deep links / navegación programática avanzada | ⬜ Falta |

---

## Decisiones de arquitectura

1. **SwiftData** como caché local + **Supabase** como fuente de verdad en la nube — arquitectura híbrida offline-first. No revertir ninguna de las dos.
2. **`@Observable`** (Swift 5.9) en vez de `ObservableObject` — más simple, no requiere `@Published`. ViewModels se instancian con `@State` en la View, no con `@StateObject`.
3. **`@AppStorage`** para preferencias de display (usuarioEmail, usuarioNombre, avatarData, aparienciaMode, ocrAutomatico, presupuesto). Supabase SDK guarda el JWT en Keychain automáticamente. `SessionStore` suscribe a `authStateChanges` y es la fuente de verdad de autenticación — no leer `@AppStorage("isLoggedIn")` para rutear.
4. **Custom DesignSystem** centralizado en `DesignSystem.swift`. Todos los tokens de color son adaptativos (UIColor con closure para dark/light mode). Nunca hardcodear colores en Views.
5. **NavigationStack** por tab (no global). Cada tab tiene su propio stack.
6. **Prefijo `SA`** para todos los componentes compartidos del DesignSystem.
7. **Lógica en ViewModels**, cero lógica de negocio en Views. Las Views solo llaman métodos del ViewModel.
8. **`Localizable.xcstrings`** (formato moderno de Xcode 15+), no `.strings`. Usar `String(localized:)` o `.localized` en SwiftUI Text.
9. **`SupabaseService`** como singleton central. `AuthViewModel` usa `SupabaseService.shared` — ya no toma `ModelContext`. El modelo `Usuario` en SwiftData se mantiene en el container pero no se crea en código nuevo (deprecado).
10. **Sync offline-first**: al crear compra, se inserta en SwiftData inmediatamente, luego se sincroniza a Supabase en background (`Task.detached`). Si falla el sync, el dato queda en SwiftData local.

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
