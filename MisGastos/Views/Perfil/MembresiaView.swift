import SwiftUI

struct MembresiaView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ciclo: String = "mensual"
    @State private var store = UserScopedStorage.shared
    @State private var isLoading = false
    @State private var showCancelAlert = false
    @State private var errorMsg: String? = nil

    private let precioMensual: Double = 2990
    private var precioAnual: Double    { precioMensual * 12 * 0.8 }       // 28 704 ARS/año
    private var precioAnualMes: Double { precioAnual / 12 }               // 2 392 ARS/mes

    private var precioDisplay: Double { ciclo == "mensual" ? precioMensual : precioAnualMes }

    // Features
    private let featuresGratis: [(String, Bool)] = [
        ("Hasta 30 compras al mes",  true),
        ("Estadísticas básicas",     true),
        ("2 tiendas favoritas",      true),
        ("Categorías ilimitadas",    false),
        ("Exportar CSV / PDF",       false),
        ("Respaldo en la nube",      false),
    ]
    private let featuresPro: [(String, Bool)] = [
        ("Compras ilimitadas",       true),
        ("Estadísticas avanzadas",   true),
        ("Tiendas ilimitadas",       true),
        ("Categorías ilimitadas",    true),
        ("Exportar CSV / PDF",       true),
        ("Respaldo en la nube",      true),
    ]

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        planGratis
                        planPro
                        Text("Cancelá cuando quieras. Sin compromisos.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.saLabel3)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .onAppear {
            ciclo = store.billingCyclePlan == "anual" ? "anual" : "mensual"
            Task { await MembresiaService.shared.sincronizar() }
        }
        .alert("Cancelar suscripción", isPresented: $showCancelAlert) {
            Button("Cancelar plan", role: .destructive) { cancelarPlan() }
            Button("Mantener Pro", role: .cancel) {}
        } message: {
            Text("Vas a volver al plan Gratis. Podés reactivar Pro cuando quieras.")
        }
        .alert("Error", isPresented: .init(
            get: { errorMsg != nil },
            set: { if !$0 { errorMsg = nil } }
        )) {
            Button("OK", role: .cancel) { errorMsg = nil }
        } message: {
            Text(errorMsg ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient.saGreen

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 220, height: 220)
                .offset(x: -60, y: -70)
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 160, height: 160)
                .offset(x: 270, y: -20)

            VStack(spacing: 0) {
                Color.clear.frame(height: 54)

                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.18), in: Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

                Text("SÚPER AHORRO+")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .tracking(1.5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.2), in: Capsule())
                    .padding(.bottom, 10)

                Text("Elegí tu plan")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .tracking(-1)
                    .padding(.bottom, 6)

                Text("Controlá cada peso que gastás en el súper.\nCancelá cuando quieras.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 18)

                billingToggle.padding(.bottom, 24)
            }
        }
        .frame(height: 290)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 28,
                bottomTrailingRadius: 28, topTrailingRadius: 0
            )
        )
    }

    private var billingToggle: some View {
        HStack(spacing: 2) {
            togglePill("Mensual", value: "mensual")
            togglePill("Anual", badge: "-20%", value: "anual")
        }
        .padding(4)
        .background(Color.white.opacity(0.18), in: Capsule())
    }

    @ViewBuilder
    private func togglePill(_ label: String, badge: String? = nil, value: String) -> some View {
        let selected = ciclo == value
        Button {
            withAnimation(.spring(duration: 0.3)) { ciclo = value }
        } label: {
            HStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(selected ? .white : Color.saGreenDark)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(selected ? Color.saGreenDark : Color.white.opacity(0.85), in: Capsule())
                }
            }
            .foregroundStyle(selected ? Color.saGreen : .white)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(selected ? Color.white : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Plan Gratis

    private var planGratis: some View {
        SACard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 14) {
                    radioCircle(active: store.planActivo == "gratis")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gratis")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.saLabel)
                        Text("Para empezar")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.saLabel3)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                divider

                // Price
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text("$")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.saLabel3)
                    Text("0,00")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(Color.saLabel)
                        .tracking(-1.2)
                    Text("siempre")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.saLabel3)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                divider

                VStack(alignment: .leading, spacing: 11) {
                    ForEach(featuresGratis, id: \.0) { f, ok in featureRow(f, ok) }
                }
                .padding(16)

                // Botón solo visible si el plan Pro está activo (para bajar)
                if store.planActivo == "pro" {
                    Button { showCancelAlert = true } label: {
                        Text("Cancelar suscripción Pro")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.saDanger)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.saDanger.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    // MARK: - Plan Pro

    private var planPro: some View {
        ZStack(alignment: .topTrailing) {
            SACard(padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header row
                    HStack(spacing: 14) {
                        proCircle
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text("Pro")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(Color.saLabel)
                                if store.planActivo == "pro" {
                                    Text("PLAN ACTUAL")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Color.saGreen)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Color.saGreenBg, in: Capsule())
                                }
                            }
                            Text("El más elegido")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.saLabel3)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 22)
                    .padding(.bottom, 12)

                    divider

                    // Price
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text("$")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.saLabel3)
                        Text(precioDisplay.formatted(.number.precision(.fractionLength(2))))
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(Color.saLabel)
                            .tracking(-1.2)
                            .contentTransition(.numericText())
                            .animation(.spring(duration: 0.4), value: ciclo)
                        Text("/ mes")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.saLabel3)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                    if ciclo == "anual" {
                        Text("Facturado anualmente · $\(precioAnual.formatted(.number.precision(.fractionLength(0)))) ARS")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.saLabel3)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                    }

                    Spacer().frame(height: 14)
                    divider

                    VStack(alignment: .leading, spacing: 11) {
                        ForEach(featuresPro, id: \.0) { f, ok in featureRow(f, ok) }
                    }
                    .padding(16)

                    // CTA
                    SAButton(
                        title: store.planActivo == "pro" ? "Plan actual" : (isLoading ? "" : "Elegir Pro"),
                        isLoading: isLoading
                    ) {
                        guard store.planActivo != "pro" else { return }
                        suscribirPro()
                    }
                    .disabled(store.planActivo == "pro")
                    .opacity(store.planActivo == "pro" ? 0.5 : 1)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.saGreen, lineWidth: store.planActivo == "pro" ? 2 : 1)
            )

            // Badge RECOMENDADO
            Text("RECOMENDADO")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .tracking(0.6)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.saGreen, in: Capsule())
                .offset(x: -14, y: -1)
        }
    }

    // MARK: - Componentes reutilizables

    @ViewBuilder
    private func radioCircle(active: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(active ? Color.saGreen : Color.saLabel4, lineWidth: 2)
            Circle()
                .fill(Color.saGreen)
                .scaleEffect(active ? 0.55 : 0)
                .animation(.spring(duration: 0.3), value: active)
        }
        .frame(width: 22, height: 22)
    }

    private var proCircle: some View {
        let active = store.planActivo == "pro"
        return ZStack {
            Circle()
                .fill(active ? Color.saGreen : Color.clear)
                .overlay(Circle().stroke(active ? Color.saGreen : Color.saLabel4, lineWidth: 2))
            if active {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 22, height: 22)
    }

    @ViewBuilder
    private func featureRow(_ text: String, _ included: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: included ? "checkmark" : "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(included ? Color.saGreen : Color.saLabel4)
                .frame(width: 16, alignment: .center)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(included ? Color.saLabel : Color.saLabel3)
                .strikethrough(!included, color: Color.saLabel4)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.saSep)
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    // MARK: - Acciones

    private func suscribirPro() {
        isLoading = true
        Task {
            do {
                try await MembresiaService.shared.suscribirPro(billingCycle: ciclo)
            } catch {
                errorMsg = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func cancelarPlan() {
        Task {
            do {
                try await MembresiaService.shared.cancelarPlan()
            } catch {
                errorMsg = error.localizedDescription
            }
        }
    }
}
