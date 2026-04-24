import SwiftUI

// MARK: - Color Tokens
extension Color {
    static let saGreen      = Color(hex: "#22C55E")
    static let saGreenDark  = Color(hex: "#16A34A")
    static let saGreenLight = Color(hex: "#4ADE80")
    static let saGreenBg    = Color(hex: "#22C55E").opacity(0.1)
    static let saBg         = Color(hex: "#F6F8F6")
    static let saCard       = Color.white
    static let saLabel      = Color(hex: "#111111")
    static let saLabel2     = Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.6)
    static let saLabel3     = Color(hex: "#8E8E93")
    static let saLabel4     = Color(hex: "#C7C7CC")
    static let saSep        = Color(hex: "#E5E7EB")
    static let saDanger     = Color(hex: "#EF4444")

    // Legacy aliases so old code still compiles
    static let brand        = saGreen
    static let brandBg      = saGreenBg
    static let txtPrimary   = saLabel
    static let txtSecondary = saLabel3
    static let border       = saSep
    static let surface      = saBg
    static let inputBg      = saBg
    static let danger       = saDanger

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

// MARK: - Green Gradient
extension LinearGradient {
    static var saGreen: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(hex: "#4ADE80"), location: 0),
                .init(color: Color(hex: "#22C55E"), location: 0.55),
                .init(color: Color(hex: "#16A34A"), location: 1),
            ],
            startPoint: UnitPoint(x: 0.2, y: 0),
            endPoint: UnitPoint(x: 0.8, y: 1)
        )
    }
}

// MARK: - Store Data
struct SAStoreInfo {
    let color: Color
    let initials: String
}

let saSupermercados: [String] = ["Coto", "Carrefour", "Día", "Jumbo", "Disco", "Vea", "Chino local", "Walmart"]

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

func saStoreInfo(for name: String) -> SAStoreInfo {
    if let info = _saStoreMap[name] { return info }
    if let key = _saStoreMap.keys.first(where: { $0.lowercased() == name.lowercased() }),
       let info = _saStoreMap[key] { return info }
    let hash = abs(name.hashValue)
    let hue = Double(hash % 360) / 360.0
    return SAStoreInfo(
        color: Color(hue: hue, saturation: 0.55, brightness: 0.65),
        initials: String(name.prefix(2)).uppercased()
    )
}

let saMetodosPago: [String] = ["Efectivo", "Débito", "Crédito", "Mercado Pago", "Transferencia"]

// MARK: - BrandMark
struct SABrandMark: View {
    var size: CGFloat = 80
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26)
                .fill(LinearGradient.saGreen)
                .frame(width: size, height: size)
            Image(systemName: "cart.fill")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Store Avatar
struct SAStoreAvatar: View {
    let name: String
    var size: CGFloat = 42
    var body: some View {
        let info = saStoreInfo(for: name)
        ZStack {
            Circle()
                .fill(info.color)
                .frame(width: size, height: size)
            Text(info.initials)
                .font(.system(size: size * 0.33, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Card
struct SACard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.saCard)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.03), radius: 1, y: 1)
        .shadow(color: .black.opacity(0.04), radius: 16, y: 4)
    }
}

// MARK: - Field
struct SAField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var isSecure: Bool = false
    @State private var showPassword = false

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.saLabel3)
                    .frame(width: 20)
            }
            Group {
                if isSecure && !showPassword {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.system(size: 17))
            .autocorrectionDisabled()
            if isSecure {
                Button { showPassword.toggle() } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(Color.saLabel3)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Primary Button
struct SAButton: View {
    let title: String
    var isLoading: Bool = false
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isDestructive {
                    RoundedRectangle(cornerRadius: 14).fill(Color.white)
                    RoundedRectangle(cornerRadius: 14).stroke(Color.saSep, lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: 14).fill(LinearGradient.saGreen)
                }
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
        .disabled(isLoading)
    }
}

// MARK: - Legacy wrappers (NuevoProductoView, EditarPerfilView still use these)
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

struct MGStatusBar: View {
    var body: some View { Color.clear.frame(height: 44) }
}

struct MGHomeIndicator: View {
    var body: some View { Color.clear.frame(height: 8) }
}
