// =============================================================================
// MembresiaView.swift — Pantalla de selección de plan de membresía
// =============================================================================
// Rol en la app:
//   Sheet que presenta los planes Gratis y Pro de Súper Ahorro, con toggle
//   de ciclo de facturación (mensual/anual) y lista de features por plan.
//   Al confirmar, llama a `MembresiaService` para upsert en la tabla `membresias`
//   de Supabase y actualiza `UserScopedStorage` localmente.
//
// Equivalente Android:
//   Una `Activity` o `BottomSheetDialogFragment` con una pantalla de precios
//   tipo Google Play Billing. El proceso de suscripción se haría con
//   `BillingClient` (Play Billing Library). En este TP se simula con Supabase.
//
// `contentTransition(.numericText())`:
//   Animación especial de SwiftUI (iOS 17+) que anima el cambio de dígitos en
//   un `Text` como si fuera un contador. Al cambiar entre precio mensual y
//   precio anual, los números se animan individualmente. Equivalente Android:
//   `CountingTextView` de terceros o animación manual con `ValueAnimator`.
//
// `UnevenRoundedRectangle`:
//   Equivalente iOS 16+ de `RoundedRectangle` pero con radios distintos por esquina.
//   Aquí se usa en el header para redondear solo las esquinas inferiores del banner
//   verde, creando el efecto de "carta" que se superpone al contenido siguiente.
//   Equivalente Android: `MaterialShapeDrawable` con `ShapeAppearanceModel` y
//   `CornerFamily.ROUNDED` solo en las esquinas inferiores.
// =============================================================================

import SwiftUI

/// Pantalla de membresía con planes Gratis y Pro.
///
/// Equivalente Android: pantalla de paywall con `RecyclerView` de planes y
/// integración con `BillingClient` de Google Play.
struct MembresiaView: View {

    // MARK: - Entorno y estado

    /// Permite cerrar la sheet.
    @Environment(\.dismiss) private var dismiss

    /// Ciclo de facturación seleccionado: "mensual" o "anual".
    @State private var ciclo: String = "mensual"

    /// Preferencias del usuario — fuente de verdad del plan activo.
    @State private var store = UserScopedStorage.shared

    /// `true` mientras se procesa la suscripción con Supabase.
    @State private var isLoading = false

    /// Controla el alert de confirmación para cancelar el plan Pro.
    @State private var showCancelAlert = false

    /// Mensaje de error a mostrar en un alert si falla la operación.
    @State private var errorMsg: String? = nil

    // MARK: - Cálculo de precios

    /// Precio mensual del plan Pro en ARS.
    private let precioMensual: Double = 2990

    /// Precio anual total con 20% de descuento respecto al mensual.
    /// `2990 * 12 * 0.8 = 28.704 ARS/año`
    private var precioAnual: Double    { precioMensual * 12 * 0.8 }

    /// Precio equivalente por mes del plan anual (para mostrar en la tarjeta Pro).
    private var precioAnualMes: Double { precioAnual / 12 }

    /// Precio a mostrar en la UI según el ciclo seleccionado (por mes, siempre).
    private var precioDisplay: Double { ciclo == "mensual" ? precioMensual : precioAnualMes }

    // MARK: - Features por plan

    /// Features del plan Gratis: nombre + si está incluido.
    private let featuresGratis: [(String, Bool)] = [
        ("Hasta 30 compras al mes",  true),
        ("Estadísticas básicas",     true),
        ("2 tiendas favoritas",      true),
        ("Categorías ilimitadas",    false),  // Tachado en la UI (strikethrough)
        ("Exportar CSV / PDF",       false),
        ("Respaldo en la nube",      false),
    ]

    /// Features del plan Pro: todas incluidas.
    private let featuresPro: [(String, Bool)] = [
        ("Compras ilimitadas",       true),
        ("Estadísticas avanzadas",   true),
        ("Tiendas ilimitadas",       true),
        ("Categorías ilimitadas",    true),
        ("Exportar CSV / PDF",       true),
        ("Respaldo en la nube",      true),
    ]

    // MARK: - Vista principal

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()
            VStack(spacing: 0) {
                header   // Banner verde con toggle de ciclo
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        planGratis   // Tarjeta del plan Gratis
                        planPro      // Tarjeta del plan Pro con CTA
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
            // Sincronizar el ciclo de facturación con el guardado en Supabase
            ciclo = store.billingCyclePlan == "anual" ? "anual" : "mensual"
            // Refrescar el estado del plan desde Supabase
            Task { await MembresiaService.shared.sincronizar() }
        }
        // Alert de confirmación para cancelar el plan Pro
        .alert("Cancelar suscripción", isPresented: $showCancelAlert) {
            Button("Cancelar plan", role: .destructive) { cancelarPlan() }
            Button("Mantener Pro", role: .cancel) {}
        } message: {
            Text("Vas a volver al plan Gratis. Podés reactivar Pro cuando quieras.")
        }
        // Alert de error genérico
        .alert("Error", isPresented: .init(
            get: { errorMsg != nil },
            set: { if !$0 { errorMsg = nil } }
        )) {
            Button("OK", role: .cancel) { errorMsg = nil }
        } message: {
            Text(errorMsg ?? "")
        }
    }

    // MARK: - Header con gradiente

    /// Banner verde con título, subtítulo y toggle de ciclo de facturación.
    ///
    /// `UnevenRoundedRectangle` redondea solo las esquinas inferiores (28pt)
    /// para crear el efecto de banner que se corta limpiamente arriba (esquinas cuadradas
    /// porque está en el top de la pantalla) y se curva abajo hacia el contenido.
    private var header: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient.saGreen

            // Círculos decorativos semitransparentes en el header
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 220, height: 220)
                .offset(x: -60, y: -70)
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 160, height: 160)
                .offset(x: 270, y: -20)

            VStack(spacing: 0) {
                Color.clear.frame(height: 54)  // Espacio para la barra de estado

                // Botón de retroceso
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

                // Badge de marca
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

                // Toggle de ciclo de facturación: Mensual / Anual (-20%)
                billingToggle.padding(.bottom, 24)
            }
        }
        .frame(height: 290)
        // Esquinas superiores cuadradas, inferiores redondeadas (28pt)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 28,
                bottomTrailingRadius: 28, topTrailingRadius: 0
            )
        )
    }

    /// Toggle segmentado para elegir ciclo de facturación: Mensual o Anual.
    ///
    /// El botón "Anual" tiene un badge "-20%" que indica el descuento.
    /// La animación de cambio usa `.spring(duration: 0.3)` para un efecto fluido.
    private var billingToggle: some View {
        HStack(spacing: 2) {
            togglePill("Mensual", value: "mensual")
            togglePill("Anual", badge: "-20%", value: "anual")
        }
        .padding(4)
        .background(Color.white.opacity(0.18), in: Capsule())
    }

    /// Pastilla del toggle de ciclo — fondo blanco si está activo, transparente si no.
    @ViewBuilder
    private func togglePill(_ label: String, badge: String? = nil, value: String) -> some View {
        let selected = ciclo == value
        Button {
            withAnimation(.spring(duration: 0.3)) { ciclo = value }
        } label: {
            HStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                // Badge con descuento (solo para el plan anual)
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

    // MARK: - Tarjeta del plan Gratis

    /// Tarjeta del plan Gratis con radio button, precio $0 y lista de features.
    ///
    /// Si el plan activo es Pro, muestra un botón destructivo para cancelar
    /// y volver al plan Gratis (visible solo en ese caso).
    private var planGratis: some View {
        SACard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // Encabezado: radio button + nombre del plan
                HStack(spacing: 14) {
                    // Radio button — activo si el plan actual es "gratis"
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

                // Precio: $0 siempre
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

                // Lista de features con checkmarks/cruces
                VStack(alignment: .leading, spacing: 11) {
                    ForEach(featuresGratis, id: \.0) { f, ok in featureRow(f, ok) }
                }
                .padding(16)

                // Botón destructivo para cancelar Pro — solo visible si el usuario tiene Pro
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

    // MARK: - Tarjeta del plan Pro

    /// Tarjeta del plan Pro con badge "RECOMENDADO", precio animado y CTA.
    ///
    /// `contentTransition(.numericText())` anima el cambio de precio cuando el usuario
    /// cambia entre ciclo mensual y anual. Los dígitos se deslizan individualmente.
    /// Equivalente Android: `CountingTextView` de terceros o animación con `ValueAnimator`.
    private var planPro: some View {
        ZStack(alignment: .topTrailing) {
            SACard(padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    // Encabezado: radio button + nombre + badge "PLAN ACTUAL"
                    HStack(spacing: 14) {
                        proCircle  // Círculo verde con checkmark si el plan es Pro
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text("Pro")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(Color.saLabel)
                                // Badge "PLAN ACTUAL" solo si está suscripto
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

                    // Precio con animación de dígitos al cambiar el ciclo
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text("$")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.saLabel3)
                        Text(precioDisplay.formatted(.number.precision(.fractionLength(2))))
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(Color.saLabel)
                            .tracking(-1.2)
                            // `contentTransition` anima el cambio de texto como contador animado
                            .contentTransition(.numericText())
                            .animation(.spring(duration: 0.4), value: ciclo)
                        Text("/ mes")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.saLabel3)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                    // Nota adicional para el ciclo anual (total facturado)
                    if ciclo == "anual" {
                        Text("Facturado anualmente · $\(precioAnual.formatted(.number.precision(.fractionLength(0)))) ARS")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.saLabel3)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                    }

                    Spacer().frame(height: 14)
                    divider

                    // Lista de features Pro (todas incluidas)
                    VStack(alignment: .leading, spacing: 11) {
                        ForEach(featuresPro, id: \.0) { f, ok in featureRow(f, ok) }
                    }
                    .padding(16)

                    // CTA: "Elegir Pro" (o "Plan actual" si ya está suscripto)
                    SAButton(
                        title: store.planActivo == "pro" ? "Plan actual" : (isLoading ? "" : "Elegir Pro"),
                        isLoading: isLoading
                    ) {
                        guard store.planActivo != "pro" else { return }
                        suscribirPro()
                    }
                    .disabled(store.planActivo == "pro")
                    .opacity(store.planActivo == "pro" ? 0.5 : 1)  // Opacidad reducida si ya es Pro
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            // Borde verde: 2pt si es el plan actual, 1pt si no
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.saGreen, lineWidth: store.planActivo == "pro" ? 2 : 1)
            )

            // Badge "RECOMENDADO" en la esquina superior derecha de la tarjeta
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

    /// Radio button para el plan Gratis.
    /// Muestra un punto verde interno (active) o solo el borde (inactive).
    @ViewBuilder
    private func radioCircle(active: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(active ? Color.saGreen : Color.saLabel4, lineWidth: 2)
            Circle()
                .fill(Color.saGreen)
                .scaleEffect(active ? 0.55 : 0)  // Escala de 0 a visible con animación spring
                .animation(.spring(duration: 0.3), value: active)
        }
        .frame(width: 22, height: 22)
    }

    /// Indicador circular para el plan Pro.
    /// Verde con checkmark si activo; outline gris si no.
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

    /// Fila de feature con ícono checkmark (incluido) o X (no incluido).
    ///
    /// Las features no incluidas se muestran con texto tachado (strikethrough)
    /// y color atenuado, patrón común en páginas de precios.
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
                .strikethrough(!included, color: Color.saLabel4)  // Tachado si no está incluido
        }
    }

    /// Separador horizontal fino entre secciones de la tarjeta.
    private var divider: some View {
        Rectangle()
            .fill(Color.saSep)
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    // MARK: - Acciones

    /// Suscribe al usuario al plan Pro con el ciclo seleccionado.
    ///
    /// Llama a `MembresiaService.shared.suscribirPro()` que hace upsert en la tabla
    /// `membresias` de Supabase y actualiza `UserScopedStorage` con el nuevo plan.
    /// Equivalente Android: `billingClient.launchBillingFlow()` con el SKU de Pro.
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

    /// Cancela el plan Pro y vuelve al plan Gratis.
    ///
    /// Llama a `MembresiaService.shared.cancelarPlan()` que hace upsert en Supabase
    /// con plan `"gratis"` y limpia la fecha de renovación.
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
