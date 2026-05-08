// =============================================================================
// DesignSystem.swift — Sistema de diseño centralizado de Súper Ahorro
// =============================================================================
// Rol en la app:
//   Define todos los tokens de diseño (colores, gradientes), datos constantes
//   (supermercados, métodos de pago) y componentes de UI reutilizables. Es la
//   fuente de verdad visual de la app — ninguna View debería hardcodear colores
//   o estilos fuera de este archivo.
//
// Equivalente Android:
//   En Android, el sistema de diseño equivalente se implementa en:
//   - `res/values/colors.xml` → tokens de color estáticos.
//   - `ui/theme/Theme.kt` y `Color.kt` → colores adaptativos con `MaterialTheme`.
//   - `ui/theme/Type.kt` → tipografía.
//   - `@Composable fun` en un módulo `:designsystem` → componentes reutilizables.
//   Aquí en iOS, todo está en un solo archivo Swift usando extensiones y structs.
//
// Colores adaptativos:
//   Los tokens de color usan `UIColor` con un closure `{ traitCollection in ... }`
//   que iOS llama cada vez que cambia entre modo claro y oscuro. Esto garantiza
//   que la UI se actualiza automáticamente sin código adicional.
//   Equivalente Android: `@color/saCard` en `res/values/colors.xml` (modo claro)
//   y `res/values-night/colors.xml` (modo oscuro).
//
// Convenciones de nombres:
//   - Prefijo `sa` (Súper Ahorro) en todos los tokens: `saGreen`, `saBg`, `saCard`.
//   - Prefijo `SA` en structs de componentes: `SACard`, `SAField`, `SAButton`.
//   - Prefijo `MG` en wrappers legacy (no usar en código nuevo).
// =============================================================================

import SwiftUI

// MARK: - Tokens de Color

/// Extensión de `Color` con todos los tokens de diseño de la app.
///
/// Los tokens se dividen en:
/// - **Colores de marca**: verde brand, siempre igual en claro y oscuro.
/// - **Tokens adaptativos**: cambian automáticamente con el modo del sistema.
/// - **Aliases legacy**: mantienen compatibilidad con código antiguo.
///
/// Equivalente Android: objetos `Color` en `ui/theme/Color.kt` de Material Design.
extension Color {

    // MARK: Verdes de marca (iguales en ambos modos)

    /// Verde principal de la marca — usado en botones, íconos y acentos.
    static let saGreen      = Color(hex: "#22C55E")

    /// Verde más oscuro — hover, sombras de botón, elementos de énfasis.
    static let saGreenDark  = Color(hex: "#16A34A")

    /// Verde más claro — highlights, indicadores activos.
    static let saGreenLight = Color(hex: "#4ADE80")

    // MARK: Fondo con tinte verde (adaptativo)

    /// Fondo con tinte verde sutil — usado en cards de resumen, badges Pro.
    /// En modo oscuro se usa opacidad mayor (0.18) para mantener visibilidad.
    static let saGreenBg = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 0.18)
            : UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 0.10)
    })

    // MARK: Superficie principal (adaptativo)

    /// Color de fondo principal de la app — casi negro en dark, gris muy claro en light.
    static let saBg = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.055, green: 0.063, blue: 0.082, alpha: 1)   // #0E1015
            : UIColor(red: 0.965, green: 0.973, blue: 0.965, alpha: 1)   // #F6F8F6
    })

    /// Color de fondo de cards y superficies elevadas — negro oscuro en dark, blanco en light.
    ///
    /// Las cards usan un color diferente al fondo para crear la ilusión de profundidad
    /// sin necesidad de sombras en modo oscuro (patrón estándar de iOS HIG).
    static let saCard = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.114, green: 0.122, blue: 0.149, alpha: 1)   // #1D1F26
            : UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1)   // #FFFFFF
    })

    // MARK: Texto (adaptativo)

    /// Texto primario — casi blanco en dark, casi negro en light.
    static let saLabel = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.949, green: 0.949, blue: 0.969, alpha: 1)   // #F2F2F7
            : UIColor(red: 0.067, green: 0.067, blue: 0.067, alpha: 1)   // #111111
    })

    /// Texto secundario — 60% de opacidad sobre el color de texto primario.
    /// Equivale al `secondaryLabel` del iOS HIG para subtítulos y metadata.
    static let saLabel2 = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.922, green: 0.922, blue: 0.961, alpha: 0.6)
            : UIColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.6)
    })

    /// Texto terciario — placeholders y etiquetas de baja jerarquía.
    /// Equivale al `tertiaryLabel` del iOS HIG.
    static let saLabel3 = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.388, green: 0.388, blue: 0.400, alpha: 1)   // #636366
            : UIColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1)   // #8E8E93
    })

    /// Texto cuaternario — elementos muy sutiles como separadores de sección.
    static let saLabel4 = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.227, green: 0.227, blue: 0.235, alpha: 1)   // #3A3A3C
            : UIColor(red: 0.780, green: 0.780, blue: 0.800, alpha: 1)   // #C7C7CC
    })

    // MARK: Separadores y peligro

    /// Color de separadores y bordes de campos — sutil, adaptativo.
    static let saSep = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.173, green: 0.173, blue: 0.180, alpha: 1)   // #2C2C2E
            : UIColor(red: 0.898, green: 0.906, blue: 0.921, alpha: 1)   // #E5E7EB
    })

    /// Color de acciones destructivas (eliminar, cancelar plan) — rojo igual en ambos modos.
    static let saDanger = Color(hex: "#EF4444")

    // MARK: Aliases legacy (compatibilidad con código anterior)

    /// Alias para `saGreen` — no usar en código nuevo.
    static let brand        = saGreen
    /// Alias para `saGreenBg`.
    static let brandBg      = saGreenBg
    /// Alias para `saLabel`.
    static let txtPrimary   = saLabel
    /// Alias para `saLabel3`.
    static let txtSecondary = saLabel3
    /// Alias para `saSep`.
    static let border       = saSep
    /// Alias para `saBg`.
    static let surface      = saBg
    /// Alias para `saBg`.
    static let inputBg      = saBg
    /// Alias para `saDanger`.
    static let danger       = saDanger

    // MARK: Inicializador hexadecimal

    /// Crea un `Color` desde un string hexadecimal con o sin `#`.
    ///
    /// Soporta formato `#RRGGBB` y `RRGGBB`.
    /// Equivalente Android: `Color(0xFFRRGGBB)` o `colorResource(R.color.saGreen)`.
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >>  8) & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}

// MARK: - Gradiente Verde de Marca

/// Extensión de `LinearGradient` con el gradiente principal de la app.
///
/// El gradiente va de verde claro (esquina superior izquierda) a verde oscuro
/// (esquina inferior derecha), dando profundidad a botones y headers.
/// Equivalente Android: `<gradient>` en XML o `Brush.linearGradient()` en Compose.
extension LinearGradient {
    /// Gradiente verde diagonal — usado en botones, headers, cards destacadas.
    static var saGreen: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(hex: "#4ADE80"), location: 0),     // Verde claro arriba
                .init(color: Color(hex: "#22C55E"), location: 0.55),   // Verde brand en el centro
                .init(color: Color(hex: "#16A34A"), location: 1),     // Verde oscuro abajo
            ],
            startPoint: UnitPoint(x: 0.2, y: 0),   // Inicio: 20% desde la izquierda, arriba
            endPoint: UnitPoint(x: 0.8, y: 1)      // Fin: 80% desde la izquierda, abajo
        )
    }
}

// MARK: - Datos de Supermercados

/// Datos de un supermercado: color de marca e iniciales para el avatar.
///
/// Se usa en `SAStoreAvatar` para mostrar el logo/color de cada cadena.
/// Equivalente Android: un `data class` con `color: Int` y `initials: String`.
struct SAStoreInfo {
    let color: Color
    let initials: String
}

/// Lista hardcodeada de supermercados soportados por la app.
///
/// Esta lista se usa como fallback cuando la API de Supabase no está disponible.
/// `NetworkService` intentará obtener la lista actualizada desde Supabase primero.
/// Equivalente Android: array en `strings.xml` o `BuildConfig` constant.
let saSupermercados: [String] = ["Coto", "Carrefour", "Día", "Jumbo", "Disco", "Vea", "Chino local", "Walmart"]

/// Mapa privado de información de marca por nombre de supermercado.
///
/// Contiene los colores corporativos reales de cada cadena y sus iniciales.
/// Solo se accede a través de `saStoreInfo(for:)` que maneja el fallback.
private let _saStoreMap: [String: SAStoreInfo] = [
    "Coto":        SAStoreInfo(color: Color(hex: "#E30613"), initials: "CO"),
    "Carrefour":   SAStoreInfo(color: Color(hex: "#1D3F8D"), initials: "CA"),
    "Día":         SAStoreInfo(color: Color(hex: "#E2231A"), initials: "DÍ"),
    "Jumbo":       SAStoreInfo(color: Color(hex: "#00A859"), initials: "JU"),
    "Disco":       SAStoreInfo(color: Color(hex: "#0067B1"), initials: "DI"),
    "Vea":         SAStoreInfo(color: Color(hex: "#FFC20E"), initials: "VE"),
    "Chino local": SAStoreInfo(color: Color(hex: "#6B7280"), initials: "CH"),
    "Walmart":     SAStoreInfo(color: Color(hex: "#0071CE"), initials: "WM"),
]

/// Devuelve la información de marca de un supermercado por nombre.
///
/// Estrategia de fallback para nombres desconocidos:
/// 1. Buscar exacto en el mapa.
/// 2. Buscar case-insensitive (por si la API devuelve "carrefour" en minúscula).
/// 3. Generar color único a partir del hash del nombre (determinístico, siempre igual).
///
/// - Parameter name: Nombre del supermercado tal como se guardó en la compra.
/// - Returns: `SAStoreInfo` con color e iniciales para el avatar.
func saStoreInfo(for name: String) -> SAStoreInfo {
    if let info = _saStoreMap[name] { return info }
    // Búsqueda case-insensitive como segundo intento
    if let key = _saStoreMap.keys.first(where: { $0.lowercased() == name.lowercased() }),
       let info = _saStoreMap[key] { return info }
    // Fallback: color generado a partir del hash del nombre (siempre consistente)
    let hash = abs(name.hashValue)
    let hue = Double(hash % 360) / 360.0
    return SAStoreInfo(
        color: Color(hue: hue, saturation: 0.55, brightness: 0.65),
        initials: String(name.prefix(2)).uppercased()
    )
}

/// Lista de métodos de pago disponibles en la app.
///
/// Se usa en `PaymentPickerSheet` y en el formulario de nueva compra.
let saMetodosPago: [String] = ["Efectivo", "Débito", "Crédito", "Mercado Pago", "Transferencia"]

// MARK: - SABrandMark

/// Logo/ícono principal de la app: gradiente verde con ícono de carrito.
///
/// Se usa en `SplashView` y en headers de pantallas de auth.
/// Equivalente Android: `ImageView` con el drawable del ícono de la app.
struct SABrandMark: View {
    /// Tamaño del ícono en puntos (pt). El ícono interior escala proporcionalmente.
    var size: CGFloat = 80

    var body: some View {
        ZStack {
            // Fondo con esquinas redondeadas y gradiente verde de marca
            RoundedRectangle(cornerRadius: size * 0.26)
                .fill(LinearGradient.saGreen)
                .frame(width: size, height: size)
            // Ícono de carrito de compras en blanco
            Image(systemName: "cart.fill")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - SAStoreAvatar

/// Avatar circular que muestra el color e iniciales de un supermercado.
///
/// Si el supermercado está en `_saStoreMap`, usa sus colores corporativos.
/// Si no, genera un color determinístico a partir del nombre.
/// Equivalente Android: `CircleImageView` con color de fondo dinámico.
struct SAStoreAvatar: View {
    /// Nombre del supermercado — se busca en `saStoreInfo(for:)`.
    let name: String

    /// Diámetro del círculo en puntos.
    var size: CGFloat = 42

    var body: some View {
        let info = saStoreInfo(for: name)
        ZStack {
            // Fondo circular con el color de la cadena
            Circle()
                .fill(info.color)
                .frame(width: size, height: size)
            // Iniciales de la cadena en blanco
            Text(info.initials)
                .font(.system(size: size * 0.33, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - SACard

/// Contenedor genérico con fondo de card, rounding y sombras sutiles.
///
/// Wrapper alrededor de `VStack` que aplica el estilo de card estándar.
/// `@ViewBuilder` permite usar múltiples vistas dentro de `SACard { }`.
/// Equivalente Android: `CardView` de Material Design o un `Surface` en Compose.
struct SACard<Content: View>: View {
    /// Padding interno del contenido de la card.
    var padding: CGFloat = 16

    /// Contenido de la card — cualquier combinación de vistas SwiftUI.
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.saCard)                                    // Adaptativo: blanco / oscuro
        .clipShape(RoundedRectangle(cornerRadius: 20))
        // Doble sombra para dar mayor profundidad visual (técnica estándar en iOS design)
        .shadow(color: .black.opacity(0.03), radius: 1, y: 1)       // Sombra cercana, sutil
        .shadow(color: .black.opacity(0.04), radius: 16, y: 4)      // Sombra difusa, profundidad
    }
}

// MARK: - SAField

/// Campo de texto estilizado con ícono opcional y toggle de contraseña.
///
/// Reemplaza al `TextField`/`SecureField` nativo con el estilo visual de la app.
/// Soporta dos modos:
/// - Texto normal: `TextField` con placeholder y ícono opcional.
/// - Contraseña: `SecureField` con botón de ojo para mostrar/ocultar.
///
/// Equivalente Android: `TextInputLayout` + `TextInputEditText` de Material Design,
/// o `OutlinedTextField` en Compose con `trailingIcon` para el toggle de contraseña.
struct SAField: View {
    /// Texto del placeholder cuando el campo está vacío.
    let placeholder: String

    /// Texto ingresado por el usuario — binding bidireccional con la View padre.
    @Binding var text: String

    /// Nombre del SF Symbol a mostrar a la izquierda del campo (opcional).
    var icon: String? = nil

    /// Si es `true`, el texto se oculta con bullets y se muestra el botón de ojo.
    var isSecure: Bool = false

    /// Controla si la contraseña se muestra en texto claro.
    @State private var showPassword = false

    var body: some View {
        HStack(spacing: 10) {
            // Ícono izquierdo (opcional)
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.saLabel3)
                    .frame(width: 20)
            }
            // Campo de texto — normal o seguro dependiendo del modo
            Group {
                if isSecure && !showPassword {
                    SecureField(placeholder, text: $text)    // Bullets
                } else {
                    TextField(placeholder, text: $text)      // Texto visible
                }
            }
            .font(.system(size: 17))
            .autocorrectionDisabled()   // No corregir emails ni contraseñas
            // Toggle de visibilidad de contraseña
            if isSecure {
                Button { showPassword.toggle() } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(Color.saLabel3)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color.saCard)                         // Fondo adaptativo claro/oscuro
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.saSep, lineWidth: 1)        // Borde separador sutil
        )
    }
}

// MARK: - SAButton

/// Botón primario de la app con estado de carga y variante destructiva.
///
/// Dos variantes:
/// - **Normal**: fondo con gradiente verde, texto blanco.
/// - **Destructivo**: fondo de card, borde de separador, texto rojo.
///
/// Cuando `isLoading == true`, muestra un `ProgressView` y deshabilita la acción
/// para evitar múltiples taps mientras se procesa una operación asíncrona.
///
/// Equivalente Android: `Button` de Material Design en Compose con `CircularProgressIndicator`
/// superpuesto, o `MaterialButton` con `isEnabled = false` en View system.
struct SAButton: View {
    /// Texto del botón.
    let title: String

    /// Si es `true`, muestra un spinner y deshabilita el botón.
    var isLoading: Bool = false

    /// Si es `true`, usa la variante destructiva (rojo, sin gradiente).
    var isDestructive: Bool = false

    /// Acción ejecutada al tocar el botón.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Fondo: gradiente verde (normal) o card con borde (destructivo)
                if isDestructive {
                    RoundedRectangle(cornerRadius: 14).fill(Color.saCard)
                    RoundedRectangle(cornerRadius: 14).stroke(Color.saSep, lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: 14).fill(LinearGradient.saGreen)
                }
                // Contenido: spinner de carga o texto del botón
                if isLoading {
                    ProgressView().tint(isDestructive ? Color.saLabel3 : .white)
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isDestructive ? Color.saDanger : .white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .disabled(isLoading)   // Deshabilitar durante carga para evitar doble submit
    }
}

// MARK: - Wrappers legacy

/// Wrapper legacy que agrega un label encima de `SAField`.
///
/// No usar en código nuevo — preferir `SAField` directamente con VStack en la View.
struct MGInputField: View {
    let label: String
    let placeholder: String
    let icon: String
    @Binding var text: String
    var isSecure = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.saLabel)
            SAField(placeholder: placeholder, text: $text, icon: icon, isSecure: isSecure)
        }
    }
}

/// Wrapper legacy que delega a `SAButton`.
///
/// No usar en código nuevo — preferir `SAButton` directamente.
struct MGButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isLoading = false
    var isDestructive = false
    init(_ title: String, icon: String? = nil, isLoading: Bool = false,
         isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title; self.icon = icon
        self.isLoading = isLoading; self.isDestructive = isDestructive; self.action = action
    }
    var body: some View {
        SAButton(title: title, isLoading: isLoading, isDestructive: isDestructive, action: action)
    }
}

/// Espaciador legacy para la status bar — no usar en código nuevo.
struct MGStatusBar: View {
    var body: some View { Color.clear.frame(height: 44) }
}

/// Espaciador legacy para el home indicator — no usar en código nuevo.
struct MGHomeIndicator: View {
    var body: some View { Color.clear.frame(height: 8) }
}
