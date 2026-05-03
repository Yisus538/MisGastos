import SwiftUI

// MARK: - Mode enum (accesible en todo el módulo)

enum AparienciaMode: String, CaseIterable {
    case claro   = "claro"
    case oscuro  = "oscuro"
    case sistema = "sistema"

    var label: String {
        switch self {
        case .claro:   return "Claro"
        case .oscuro:  return "Oscuro"
        case .sistema: return "Sistema"
        }
    }

    var sublabel: String {
        switch self {
        case .claro:   return "Siempre claro"
        case .oscuro:  return "Siempre oscuro"
        case .sistema: return "Sigue al sistema"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .claro:   return .light
        case .oscuro:  return .dark
        case .sistema: return nil
        }
    }
}

// MARK: - Sheet

struct AparienciaSheet: View {
    @AppStorage("aparienciaMode") private var modeRaw: String = "sistema"
    @Environment(\.dismiss) private var dismiss

    private var current: AparienciaMode { AparienciaMode(rawValue: modeRaw) ?? .sistema }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.saLabel4)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Text("Apariencia")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.saLabel)
                .tracking(-0.4)

            Text("Elegí el estilo visual de Súper Ahorro")
                .font(.system(size: 14))
                .foregroundStyle(Color.saLabel3)
                .padding(.top, 4)
                .padding(.bottom, 28)

            // Phone mockups
            HStack(spacing: 16) {
                ForEach(AparienciaMode.allCases, id: \.rawValue) { mode in
                    modeCard(mode)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)

            // List picker
            SACard(padding: 0) {
                ForEach(Array(AparienciaMode.allCases.enumerated()), id: \.element.rawValue) { idx, mode in
                    listRow(mode: mode, isLast: idx == 2)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color.saBg.ignoresSafeArea())
    }

    // MARK: - Mode card

    @ViewBuilder
    private func modeCard(_ mode: AparienciaMode) -> some View {
        let isSelected = current == mode
        Button {
            select(mode)
        } label: {
            VStack(spacing: 10) {
                phoneMockup(mode: mode, isSelected: isSelected)
                    .frame(width: 88, height: 124)

                Text(mode.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.saLabel)

                radioButton(isSelected: isSelected)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Phone mockup

    @ViewBuilder
    private func phoneMockup(mode: AparienciaMode, isSelected: Bool) -> some View {
        ZStack {
            phoneBg(mode)
            phoneForeground(mode)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isSelected ? Color.saGreen : Color.saSep,
                        lineWidth: isSelected ? 2.5 : 1)
        )
        .shadow(color: .black.opacity(0.07), radius: 8, y: 3)
    }

    @ViewBuilder
    private func phoneBg(_ mode: AparienciaMode) -> some View {
        switch mode {
        case .claro:
            Color.white
        case .oscuro:
            Color(hex: "#1C1C1E")
        case .sistema:
            ZStack {
                Color.white
                Color(hex: "#1C1C1E").clipShape(SistemaTriangle())
            }
        }
    }

    @ViewBuilder
    private func phoneForeground(_ mode: AparienciaMode) -> some View {
        VStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 3)
                .fill(pillColor(mode))
                .frame(width: 26, height: 5)
            Circle()
                .fill(Color.saGreen)
                .frame(width: 8, height: 8)
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 6)
                    .fill(cardColor(mode))
                    .frame(height: 16)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private func pillColor(_ mode: AparienciaMode) -> Color {
        switch mode {
        case .claro:   return Color.black.opacity(0.15)
        case .oscuro:  return Color.white.opacity(0.25)
        case .sistema: return Color.gray.opacity(0.4)
        }
    }

    private func cardColor(_ mode: AparienciaMode) -> Color {
        switch mode {
        case .claro:   return Color.black.opacity(0.08)
        case .oscuro:  return Color.white.opacity(0.10)
        case .sistema: return Color.gray.opacity(0.18)
        }
    }

    // MARK: - Radio button

    @ViewBuilder
    private func radioButton(isSelected: Bool) -> some View {
        ZStack {
            if isSelected {
                Circle().fill(Color.saGreen).frame(width: 24, height: 24)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle().stroke(Color.saLabel4, lineWidth: 1.5).frame(width: 24, height: 24)
            }
        }
    }

    // MARK: - List row

    @ViewBuilder
    private func listRow(mode: AparienciaMode, isLast: Bool) -> some View {
        let isSelected = current == mode
        Button { select(mode) } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.label)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.saLabel)
                    Text(mode.sublabel)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.saLabel3)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.saGreen)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 60)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle().fill(Color.saSep).frame(height: 0.5).padding(.leading, 16)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Action

    private func select(_ mode: AparienciaMode) {
        withAnimation(.easeInOut(duration: 0.2)) { modeRaw = mode.rawValue }
        let raw = mode.rawValue
        Task.detached { try? await SupabaseService.shared.guardarApariencia(raw) }
    }
}

// MARK: - Sistema mockup shape (bottom-right triangle = dark half)

private struct SistemaTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
