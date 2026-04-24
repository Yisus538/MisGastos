import SwiftUI

struct EditarPerfilView: View {
    @AppStorage("usuarioNombre") private var nombre: String = ""
    @AppStorage("usuarioEmail")  private var email:  String = ""
    @Environment(\.dismiss) private var dismiss

    @State private var nombreEdit = ""
    @State private var emailEdit  = ""

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
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

                Text("Editar perfil")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.saLabel)
                    .tracking(-1)
                    .padding(.bottom, 28)

                VStack(spacing: 12) {
                    SAField(placeholder: "Nombre completo", text: $nombreEdit, icon: "person")
                    SAField(placeholder: "Correo electrónico", text: $emailEdit, icon: "envelope")
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }

                SAButton(title: "Guardar") {
                    nombre = nombreEdit
                    email  = emailEdit
                    dismiss()
                }
                .disabled(nombreEdit.isEmpty)
                .padding(.top, 24)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .onAppear { nombreEdit = nombre; emailEdit = email }
    }
}
