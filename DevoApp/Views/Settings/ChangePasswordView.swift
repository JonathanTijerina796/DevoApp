import SwiftUI

// MARK: - Change Password View
// Vista de configuración profunda - TabBar oculto

struct ChangePasswordView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var showCurrentPassword = false
    @State private var showNewPassword = false
    @State private var showConfirmPassword = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.accentBrand)
                    
                    Text(NSLocalizedString("change_password", comment: ""))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.primaryText)
                    
                    Text("Ingresa tu contraseña actual y la nueva contraseña")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 40)
                
                // Campos de contraseña
                VStack(spacing: 16) {
                    // Contraseña actual
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Contraseña actual")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.primaryText)
                        
                        HStack {
                            if showCurrentPassword {
                                TextField("", text: $currentPassword)
                            } else {
                                SecureField("", text: $currentPassword)
                            }
                            
                            Button {
                                showCurrentPassword.toggle()
                            } label: {
                                Image(systemName: showCurrentPassword ? "eye.slash.fill" : "eye.fill")
                                    .foregroundStyle(Color.secondaryText)
                            }
                        }
                        .padding(16)
                        .background(Color.inputBG)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.inputBorder, lineWidth: 1)
                        )
                    }
                    
                    // Nueva contraseña
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nueva contraseña")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.primaryText)
                        
                        HStack {
                            if showNewPassword {
                                TextField("", text: $newPassword)
                            } else {
                                SecureField("", text: $newPassword)
                            }
                            
                            Button {
                                showNewPassword.toggle()
                            } label: {
                                Image(systemName: showNewPassword ? "eye.slash.fill" : "eye.fill")
                                    .foregroundStyle(Color.secondaryText)
                            }
                        }
                        .padding(16)
                        .background(Color.inputBG)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.inputBorder, lineWidth: 1)
                        )
                    }
                    
                    // Confirmar contraseña
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirmar nueva contraseña")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.primaryText)
                        
                        HStack {
                            if showConfirmPassword {
                                TextField("", text: $confirmPassword)
                            } else {
                                SecureField("", text: $confirmPassword)
                            }
                            
                            Button {
                                showConfirmPassword.toggle()
                            } label: {
                                Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                                    .foregroundStyle(Color.secondaryText)
                            }
                        }
                        .padding(16)
                        .background(Color.inputBG)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.inputBorder, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                
                // Botón de guardar
                Button {
                    Task { await changePassword() }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        }
                        Text("Cambiar contraseña")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.accentBrand)
                    .cornerRadius(12)
                }
                .disabled(isLoading || currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer()
            }
        }
        .background(Color.screenBG.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("change_password", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func changePassword() async {
        // TODO: Implementar cambio de contraseña con Firebase
        isLoading = true
        defer { isLoading = false }
        
        // Validaciones
        guard !currentPassword.isEmpty else {
            await MainActor.run {
                alertMessage = "La contraseña actual es requerida"
                showAlert = true
            }
            return
        }
        
        guard newPassword.count >= 6 else {
            await MainActor.run {
                alertMessage = "La nueva contraseña debe tener al menos 6 caracteres"
                showAlert = true
            }
            return
        }
        
        guard newPassword == confirmPassword else {
            await MainActor.run {
                alertMessage = "Las contraseñas no coinciden"
                showAlert = true
            }
            return
        }
        
        // Aquí iría la lógica de cambio de contraseña con Firebase
        // Por ahora solo mostramos un mensaje de éxito
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            alertMessage = "Contraseña cambiada exitosamente"
            showAlert = true
            dismiss()
        }
    }
}

