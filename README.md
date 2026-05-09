# Súper Ahorro — iOS App

App iOS para registrar, consultar y analizar gastos de supermercado. Desarrollada como trabajo integrador para la materia **Tecnología Móviles**.

---

## Descripción

**Súper Ahorro** permite llevar un registro detallado de las compras en supermercado: productos, precios, métodos de pago y tickets de compra. Incluye estadísticas, comparativa de precios entre supermercados, presupuesto mensual, membresía Pro y sincronización en la nube mediante Supabase.

**Bundle ID**: `com.undef.superahorro.MartinezBulatovich`  
**Xcode project**: `MisGastos.xcodeproj`  
**Rama principal**: `main`

---

## Requisitos

- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+
- Cuenta en [Supabase](https://supabase.com)

---

## Configuración inicial

### 1. Clonar el repositorio

```bash
git clone <repo-url>
cd MisGastos
```

### 2. Configurar credenciales de Supabase

Crear el archivo `Secrets.xcconfig` en la raíz del proyecto (está en `.gitignore`, no se commitea):

```
SUPABASE_URL = https://<tu-proyecto>.supabase.co
SUPABASE_ANON_KEY = <tu-anon-key>
```

Hay un `Secrets.xcconfig.example` como referencia.

### 3. Configurar la base de datos

Ejecutar el SQL de `MisGastos/Resources/supabase_schema.sql` en el Dashboard de Supabase (SQL Editor). Esto crea las tablas, políticas RLS y buckets de Storage necesarios.

### 4. Abrir en Xcode

```bash
open MisGastos.xcodeproj
```

Seleccionar el esquema `MisGastos` y correr en un simulador o dispositivo con iOS 17+.

---

## Arquitectura

### Patrón general

Arquitectura **offline-first híbrida**: SwiftData como caché local + Supabase como fuente de verdad en la nube.

- Al crear una compra se guarda inmediatamente en SwiftData (`isSynced = false`), luego se sincroniza a Supabase en background.
- Al arrancar la app, `SyncService` reintenta la sincronización de cualquier dato pendiente.

### Capas

```
Views (SwiftUI)
    └── ViewModels (@Observable)
            └── Services (Supabase, Network, OCR, etc.)
                    └── SwiftData (persistencia local)
                    └── Supabase (persistencia remota)
```

### Decisiones clave

| Decisión | Razón |
|----------|-------|
| `@Observable` (Swift 5.9) en lugar de `ObservableObject` | Más simple, sin `@Published` |
| `SessionStore` singleton con `authStateChanges` | Única fuente de verdad de autenticación |
| `@AppStorage` para preferencias de UI | Persistencia ligera sin overhead de SwiftData |
| `NavigationStack` por tab | Stacks independientes, sin conflictos de navegación |
| DesignSystem centralizado | Tokens adaptativos para dark/light mode sin hardcodear colores |

---

## Estructura de carpetas

```
MisGastos/
├── MisGastos.xcodeproj/
├── MisGastosWidget/              ← Widget de iOS (WidgetKit)
└── MisGastos/
    ├── MisGastosApp.swift        ← Entry point, modelContainer
    ├── ContentView.swift
    ├── Models/
    │   ├── Compra.swift
    │   ├── Producto.swift
    │   └── Usuario.swift         ← Deprecado (compat SwiftData)
    ├── ViewModels/
    │   ├── AuthViewModel.swift
    │   ├── ComprasViewModel.swift
    │   ├── SessionStore.swift    ← Singleton; suscribe authStateChanges
    │   └── UserScopedStorage.swift
    ├── Views/
    │   ├── Auth/                 ← Splash, Login, Register, ForgotPassword
    │   ├── Compras/              ← Home, Historial, NuevaCompra, Detalle, Editar, Comparativa
    │   ├── Estadisticas/         ← Gráficos Swift Charts
    │   ├── Navigation/           ← MainTabView
    │   ├── Perfil/               ← Perfil, EditarPerfil, Settings, Apariencia, Membresia
    │   └── Productos/            ← NuevoProducto, EditarProducto
    ├── Services/
    │   ├── SupabaseService.swift ← Auth, CRUD, Storage
    │   ├── NetworkService.swift  ← Supermercados con caché
    │   ├── SyncService.swift     ← Retry sync al arrancar
    │   ├── MembresiaService.swift
    │   ├── CurrencyService.swift ← Tasas de cambio (ARS → USD/EUR/BRL)
    │   ├── ExportService.swift   ← CSV y PDF
    │   ├── TicketOCRService.swift ← Vision framework
    │   └── BiometricService.swift ← Face ID / Touch ID
    ├── Utils/
    │   ├── DesignSystem.swift
    │   ├── BarcodeScannerView.swift
    │   ├── CameraPickerView.swift
    │   ├── ActivitySheet.swift
    │   └── WidgetDataWriter.swift
    ├── Intents/
    │   └── GastosMesIntent.swift ← Siri Shortcuts (AppIntents)
    └── Resources/
        ├── Localizable.xcstrings
        └── supabase_schema.sql
```

---

## Modelos de datos

### `Compra`

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | UUID | Identificador único |
| `fecha` | Date | Fecha de la compra |
| `supermercado` | String | Nombre del supermercado |
| `total` | Double | Total calculado automáticamente |
| `metodoPago` | String | Efectivo, débito, crédito, etc. |
| `imagenTicket` | Data? | Foto del ticket (almacenamiento local) |
| `ticketURL` | String? | URL firmada en Supabase Storage |
| `isSynced` | Bool | `false` hasta sincronizar con Supabase |
| `productos` | [Producto] | Relación uno-a-muchos (cascade delete) |

### `Producto`

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | UUID | Identificador único |
| `codigo` | String | Código de barras |
| `nombre` | String | Nombre del producto |
| `descripcion` | String | Descripción opcional |
| `precio` | Double | Precio unitario |
| `isSynced` | Bool | `false` hasta sincronizar con Supabase |

---

## Servicios principales

### `SupabaseService`
Singleton central. Maneja autenticación (JWT + bcrypt), CRUD de compras/productos, subida de tickets a Storage y lectura de supermercados desde la base de datos.

### `TicketOCRService`
Usa el framework **Vision** de Apple (`VNRecognizeTextRequest` en modo `.accurate`) para extraer productos y precios de una foto del ticket. Soporta formato ARS (`$189.99`, `$1.234,56`). Filtra líneas de totales, IVA y descuentos automáticamente.

### `SyncService`
Al arrancar la app sincroniza a Supabase todas las compras con `isSynced == false`. Si no hay sesión activa, retorna inmediatamente sin hacer nada.

### `ExportService`
- **CSV**: con BOM UTF-8 (compatible con Excel). Secciones: RESUMEN + COMPRAS + PRODUCTOS.
- **PDF**: `UIGraphicsPDFRenderer` tamaño A4, header verde, cards de resumen, filas agrupadas por mes y paginación automática.

### `CurrencyService`
Obtiene tasas de cambio desde `open.er-api.com` (gratis, sin API key). Fallback a tasas hardcodeadas + caché en UserDefaults.

### `BiometricService`
Detecta Face ID / Touch ID via `LAContext`. El login guarda el email y la sesión JWT persiste en Keychain (manejado automáticamente por el SDK de Supabase).

### `MembresiaService`
Maneja el plan Gratis/Pro del usuario. Precios: $2.990/mes o $28.704/año (−20%). Persiste en la tabla `membresias` de Supabase con upsert.

---

## Features

### Autenticación
- Registro e inicio de sesión con email y contraseña (Supabase Auth)
- Recuperación de contraseña via email
- Face ID / Touch ID para acceso rápido
- Estado de sesión reactivo via `authStateChanges`

### Compras
- Crear, editar y eliminar compras
- Agregar, editar y eliminar productos (con scanner de código de barras)
- Captura de ticket desde cámara o galería
- OCR automático del ticket para prellenar productos
- Sincronización offline-first con Supabase

### Historial y estadísticas
- Historial completo con búsqueda y filtros
- Gráficos con **Swift Charts**: barras mensuales, área/línea de evolución, donut por supermercado
- Comparativa de precios de un mismo producto entre distintos supermercados
- Presupuesto mensual con barra de progreso y alerta al superarlo

### Perfil y configuración
- Editar nombre y foto de perfil (PhotosPicker, 300×300 JPEG)
- Cambiar apariencia: Claro / Oscuro / Sistema
- Notificaciones locales (recordatorio semanal configurable)
- Membresía Gratis / Pro con toggle mensual/anual
- Exportar datos en CSV o PDF
- Convertidor de precios ARS → USD / EUR / BRL

### Widget y Siri
- **Widget de iOS** (WidgetKit): tamaño pequeño, mediano y lock screen
- **Siri Shortcuts** (AppIntents): consulta de gastos del mes por voz en español

---

## DesignSystem

Centralizado en `Utils/DesignSystem.swift`. Todos los colores son adaptativos (dark/light mode).

### Tokens de color

| Token | Uso |
|-------|-----|
| `Color.saGreen` | Color brand principal |
| `Color.saGreenDark` / `saGreenLight` | Variantes del brand |
| `Color.saBg` | Fondo de pantalla |
| `Color.saCard` | Fondo de cards |
| `Color.saLabel` / `saLabel2/3/4` | Texto primario y secundario |
| `Color.saSep` | Separadores |
| `Color.saDanger` | Acciones destructivas |

### Componentes reutilizables

| Componente | Descripción |
|-----------|-------------|
| `SABrandMark(size:)` | Logo de la app |
| `SACard<Content>` | Card con sombra y bordes redondeados |
| `SAField` | Campo de texto con ícono y toggle de contraseña |
| `SAButton` | Botón primario/destructivo con estado loading |
| `SAStoreAvatar(name:size:)` | Avatar de supermercado con color por cadena |

---

## Internacionalización

Usa `Localizable.xcstrings` (formato moderno Xcode 15+). Las claves siguen la convención `entidad.campo` o `action.x`.

Actualmente: **español** (idioma base). Estructura preparada para agregar idiomas adicionales.

---

## Convenciones de código

| Ámbito | Convención |
|--------|-----------|
| Componentes UI compartidos | Prefijo `SA` (`SACard`, `SAButton`) |
| ViewModels | Sufijo `ViewModel` |
| Services | Sufijo `Service` |
| Tokens de color | Prefijo `sa` en extensión `Color` |
| Modelos SwiftData | PascalCase sin sufijo |
| Imports en ViewModels | Solo `Foundation` + `Observation` — nunca `SwiftUI` ni `SwiftData` |

---

## Autores

- **Martínez Bulatovich** — desarrollo iOS
- Trabajo Práctico Integrador — Tecnología Móviles 2026
