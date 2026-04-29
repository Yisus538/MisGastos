import SwiftUI

struct RegisterView: View {
    @State private var viewModel = AuthViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var termsAccepted = true

    private var strengthLevel: Int {
        let n = viewModel.password.count
        if n == 0 { return 0 }
        if n < 6 { return 1 }
        if n < 10 { return 2 }
        if n < 14 { return 3 }
        return 4
    }

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Back button
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.saLabel)
                            .frame(width: 36, height: 36)
                            .background(Color.saBg)
                            .clipShape(Circle())
                    }
                    .padding(.top, 56)
                    .padding(.bottom, 24)

                    Text("Creá tu cuenta")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.saLabel)
                        .tracking(-1)
                    Text("Empezá a ahorrar en segundos")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.saLabel3)
                        .padding(.top, 6)
                        .padding(.bottom, 28)

                    // Fields
                    VStack(spacing: 12) {
                        SAField(placeholder: "Nombre completo", text: $viewModel.nombre, icon: "person")
                        SAField(placeholder: "Correo electrónico", text: $viewModel.email, icon: "envelope")
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                        SAField(placeholder: "Creá una contraseña", text: $viewModel.password, icon: "lock", isSecure: true)
                    }

                    // Password strength
                    HStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(i < strengthLevel ? Color.saGreen : Color.saSep)
                                .frame(height: 3)
                                .animation(.easeInOut(duration: 0.2), value: strengthLevel)
                        }
                    }
                    .padding(.top, 14)
                    .padding(.horizontal, 2)

                    Text(strengthLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.saLabel3)
                        .padding(.top, 6)
                        .padding(.horizontal, 2)

                    // Terms
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(termsAccepted ? Color.saGreen : Color.saCard)
                                .frame(width: 22, height: 22)
                            if !termsAccepted {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.saLabel4, lineWidth: 1.5)
                                    .frame(width: 22, height: 22)
                            }
                            if termsAccepted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .onTapGesture { termsAccepted.toggle() }
                        .padding(.top, 1)

                        Text("Acepto los ") +
                        Text("Términos").foregroundColor(Color.saGreen) +
                        Text(" y la ") +
                        Text("Política de Privacidad").foregroundColor(Color.saGreen)
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(Color.saLabel3)
                    .padding(.top, 20)
                    .padding(.horizontal, 2)

                    if let error = viewModel.errorMessage {
                        Text(error).font(.caption).foregroundStyle(Color.saDanger).padding(.top, 8)
                    }

                    SAButton(title: "Crear cuenta", isLoading: viewModel.isLoading) {
                        Task { await viewModel.register(context: modelContext) }
                    }
                    .disabled(!termsAccepted)
                    .padding(.top, 16)

                    HStack(spacing: 4) {
                        Text("¿Ya tenés cuenta?")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.saLabel3)
                        Button("Iniciá sesión") { dismiss() }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.saGreen)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 22)
                    .padding(.bottom, 38)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private var strengthLabel: String {
        switch strengthLevel {
        case 0: return "Ingresá una contraseña"
        case 1: return "Contraseña débil"
        case 2: return "Contraseña regular"
        case 3: return "Contraseña buena"
        default: return "Contraseña segura"
        }
    }
}
