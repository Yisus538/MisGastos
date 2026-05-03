import SwiftUI
import PhotosUI

struct EditarPerfilView: View {
    @AppStorage("usuarioNombre") private var nombre: String = ""
    @AppStorage("usuarioEmail")  private var email:  String = ""
    @AppStorage("avatarData")    private var avatarData: Data = Data()
    @Environment(\.dismiss) private var dismiss

    @State private var nombreEdit = ""
    @State private var emailEdit  = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var isSaving = false
    @State private var isLoading = false

    private var initials: String {
        let parts = nombreEdit.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return nombreEdit.prefix(2).uppercased().isEmpty ? "SA" : nombreEdit.prefix(2).uppercased()
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
                    .padding(.bottom, 20)

                    Text("Editar perfil")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.saLabel)
                        .tracking(-1)
                        .padding(.bottom, 28)

                    // Avatar picker
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            avatarCircle
                                .frame(width: 96, height: 96)

                            Circle()
                                .fill(Color.saGreen)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                                .offset(x: 4, y: 4)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)

                    Text("Tocá para cambiar la foto")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.saLabel3)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 28)

                    // Fields
                    VStack(spacing: 12) {
                        SAField(placeholder: "Nombre completo", text: $nombreEdit, icon: "person")
                        SAField(placeholder: "Correo electrónico", text: $emailEdit, icon: "envelope")
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .disabled(true)
                            .opacity(0.55)
                    }

                    SAButton(title: "Guardar cambios", isLoading: isSaving) {
                        guardar()
                    }
                    .disabled(nombreEdit.isEmpty || isSaving)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .task {
            nombreEdit = nombre
            emailEdit  = email
            isLoading = true
            if let perfil = try? await SupabaseService.shared.fetchPerfil(),
               !perfil.nombre.isEmpty {
                nombreEdit = perfil.nombre
            }
            isLoading = false
        }
        .onChange(of: photoItem) { _, item in
            Task { await cargarFoto(item) }
        }
    }

    // MARK: - Avatar view

    @ViewBuilder
    private var avatarCircle: some View {
        if !avatarData.isEmpty, let uiImg = UIImage(data: avatarData) {
            Image(uiImage: uiImg)
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        } else {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "#FEF3C7"), Color(hex: "#FBBF24")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                Text(initials)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Color(hex: "#92400E"))
            }
        }
    }

    // MARK: - Actions

    private func cargarFoto(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let original = UIImage(data: data),
              let compressed = comprimirAvatar(original) else { return }
        await MainActor.run { avatarData = compressed }
    }

    private func guardar() {
        let nombreFinal = nombreEdit.trimmingCharacters(in: .whitespaces)
        guard !nombreFinal.isEmpty else { return }
        nombre = nombreFinal
        isSaving = true
        Task {
            try? await SupabaseService.shared.guardarPerfil(nombre: nombreFinal)
            isSaving = false
            dismiss()
        }
    }

    // Redimensiona a 300×300 px máx y comprime a JPEG 0.75 (~50–120 KB)
    private func comprimirAvatar(_ image: UIImage) -> Data? {
        let maxDim: CGFloat = 300
        let scale = min(maxDim / image.size.width, maxDim / image.size.height, 1)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: 0.75)
    }
}
