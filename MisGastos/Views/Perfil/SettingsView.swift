import SwiftUI

struct SettingsView: View {
    @AppStorage("aparienciaMode") private var aparienciaRaw: String = "sistema"
    @AppStorage("ocrAutomatico")  private var ocrAutomatico: Bool   = true

    @State private var showApariencia   = false
    @State private var showMoneda       = false
    @State private var showIdioma       = false
    @State private var showRestartAlert = false
    @State private var presupuestoStr   = ""
    @Environment(\.dismiss) private var dismiss

    @State private var store = UserScopedStorage.shared

    private let monedas: [(code: String, label: String, flag: String)] = [
        ("ARS", "Peso argentino", "🇦🇷"),
        ("USD", "Dólar", "🇺🇸"),
        ("EUR", "Euro", "🇪🇺"),
        ("BRL", "Real brasileño", "🇧🇷"),
    ]
    private let idiomas: [(code: String, label: String, flag: String)] = [
        ("es", "Español", "🇦🇷"),
        ("en", "English", "🇺🇸"),
    ]

    private var aparienciaLabel: String {
        (AparienciaMode(rawValue: aparienciaRaw) ?? .sistema).label
    }
    private var monedaLabel: String {
        monedas.first { $0.code == store.currencyCode }.map { "\($0.flag) \($0.code)" } ?? "🇦🇷 ARS"
    }
    private var idiomaLabel: String {
        idiomas.first { $0.code == store.languageCode }.map { "\($0.flag) \($0.label)" } ?? "🇦🇷 Español"
    }

    private var presupuestoActivoBinding: Binding<Bool> {
        Binding(
            get: { store.presupuestoActivo },
            set: { store.set($0, for: "presupuestoActivo") }
        )
    }

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.saGreen)
                            Text("Perfil")
                                .font(.system(size: 17))
                                .foregroundStyle(Color.saGreen)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Ajustes")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color.saLabel)
                            .tracking(-1)
                            .padding(.top, 10)
                            .padding(.bottom, 20)

                        // General
                        sectionLabel("General")
                        SACard(padding: 0) {
                            buttonRow(icon: "tag.fill", iconBg: Color.saGreen,
                                      title: "Moneda", value: monedaLabel, isLast: false) {
                                showMoneda = true
                            }
                            buttonRow(icon: "globe", iconBg: Color(hex: "#0A84FF"),
                                      title: "Idioma", value: idiomaLabel, isLast: true) {
                                showIdioma = true
                            }
                        }

                        // Apariencia
                        sectionLabel("Apariencia").padding(.top, 22)
                        SACard(padding: 0) {
                            buttonRow(icon: "eye.fill", iconBg: Color(hex: "#6366F1"),
                                      title: "Apariencia", value: aparienciaLabel, isLast: true) {
                                showApariencia = true
                            }
                        }

                        // Compras
                        sectionLabel("Compras").padding(.top, 22)
                        SACard(padding: 0) {
                            toggleRow(
                                icon: "sparkles",
                                iconBg: Color(hex: "#FF9500"),
                                title: "OCR automático de tickets",
                                binding: $ocrAutomatico,
                                isLast: false
                            )
                            // ── CORRECCIÓN: binding al store con scope de usuario ──
                            toggleRow(
                                icon: "banknote",
                                iconBg: Color.saGreen,
                                title: "Presupuesto mensual",
                                binding: presupuestoActivoBinding,
                                isLast: !store.presupuestoActivo
                            )
                            if store.presupuestoActivo {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8).fill(Color.saGreen)
                                        Image(systemName: "dollarsign")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.white)
                                    }
                                    .frame(width: 32, height: 32)
                                    TextField("Límite mensual en \(store.currencyCode)", text: $presupuestoStr)
                                        .keyboardType(.decimalPad)
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color.saLabel)
                                        .onChange(of: presupuestoStr) { _, v in
                                            let clean = v.filter { $0.isNumber || $0 == "." || $0 == "," }
                                            presupuestoStr = clean
                                            if let val = Double(clean.replacingOccurrences(of: ",", with: ".")) {
                                                // ── CORRECCIÓN: guardar con scope de usuario ──
                                                store.set(val, for: "presupuestoMensual")
                                            }
                                        }
                                    Spacer()
                                    if store.presupuestoMensual > 0 {
                                        Text(store.presupuestoMensual.formatted(.currency(code: store.currencyCode)))
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.saLabel3)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .frame(minHeight: 50)
                            }
                        }

                        // Datos
                        sectionLabel("Datos").padding(.top, 22)
                        SACard(padding: 0) {
                            plainRow(icon: "doc.plaintext.fill", iconBg: Color.saLabel3, title: "Exportar historial", value: nil, isLast: false)
                            plainRow(icon: "bookmark.fill", iconBg: Color(hex: "#10B981"), title: "Respaldo en la nube", value: nil, isLast: false)
                            plainRow(icon: "trash.fill", iconBg: Color.saDanger, title: "Borrar todos los datos", value: nil, isLast: true)
                        }

                        // Sobre
                        sectionLabel("Sobre").padding(.top, 22)
                        SACard(padding: 0) {
                            plainRow(icon: nil, iconBg: nil, title: "Ayuda y soporte", value: nil, isLast: false)
                            plainRow(icon: nil, iconBg: nil, title: "Términos de servicio", value: nil, isLast: false)
                            plainRow(icon: nil, iconBg: nil, title: "Política de privacidad", value: nil, isLast: false)
                            HStack {
                                Text("Versión")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.saLabel)
                                Spacer()
                                Text("1.0.0")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.saLabel3)
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 50)
                        }

                        // Logout
                        Button {
                            Task { try? await SupabaseService.shared.logout() }
                        } label: {
                            Text("Cerrar sesión")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.saDanger)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.saCard, in: RoundedRectangle(cornerRadius: 14))
                                .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 24)
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .onAppear {
            let val = store.presupuestoMensual
            if val > 0 {
                presupuestoStr = val.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(val))
                    : String(format: "%.2f", val)
            }
        }
        .sheet(isPresented: $showApariencia) { AparienciaSheet() }
        .confirmationDialog("Seleccioná la moneda", isPresented: $showMoneda, titleVisibility: .visible) {
            ForEach(monedas, id: \.code) { m in
                Button("\(m.flag) \(m.label) (\(m.code))") {
                    store.setCurrencyCode(m.code)
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .confirmationDialog("Seleccioná el idioma", isPresented: $showIdioma, titleVisibility: .visible) {
            ForEach(idiomas, id: \.code) { i in
                Button("\(i.flag) \(i.label)") {
                    store.setLanguageCode(i.code)
                    showRestartAlert = true
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .alert("Idioma actualizado", isPresented: $showRestartAlert) {
            Button("Entendido") {}
        } message: {
            Text("Cerrá y volvé a abrir la app para aplicar el nuevo idioma.")
        }
    }

    // MARK: - Row builders

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.saLabel3)
            .tracking(0.2)
            .padding(.horizontal, 4)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func plainRow(icon: String?, iconBg: Color?, title: String, value: String?, isLast: Bool) -> some View {
        HStack(spacing: 14) {
            if let icon, let bg = iconBg {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(bg)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                }
                .frame(width: 32, height: 32)
            }
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Color.saLabel)
            Spacer()
            if let value {
                Text(value)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.saLabel3)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.saLabel4)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(Color.saSep).frame(height: 0.5)
                    .padding(.leading, icon != nil ? 62 : 16)
            }
        }
    }

    @ViewBuilder
    private func toggleRow(icon: String, iconBg: Color, title: String, binding: Binding<Bool>, isLast: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(iconBg)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Color.saLabel)
            Spacer()
            Toggle("", isOn: binding).tint(Color.saGreen).labelsHidden()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(Color.saSep).frame(height: 0.5).padding(.leading, 62)
            }
        }
    }

    @ViewBuilder
    private func buttonRow(icon: String, iconBg: Color, title: String, value: String, isLast: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(iconBg)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                }
                .frame(width: 32, height: 32)
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.saLabel)
                Spacer()
                Text(value)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.saLabel3)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.saLabel4)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle().fill(Color.saSep).frame(height: 0.5).padding(.leading, 62)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - NotificationService

final class NotificationService {
    static let shared = NotificationService()

    func solicitarPermiso() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func programarRecordatorio(diaSemana: Int = 2, hora: Int = 10) {
        let content = UNMutableNotificationContent()
        content.title = "Súper Ahorro"
        content.body = "¿Hiciste compras esta semana? ¡Registralas ahora!"
        content.sound = .default
        var dc = DateComponents()
        dc.weekday = diaSemana; dc.hour = hora
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "recordatorio-semanal", content: content, trigger: trigger)
        )
    }
}
