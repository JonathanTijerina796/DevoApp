import SwiftUI

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hora/status bar lo maneja el simulador
                Text("")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.primaryText)
                    .padding(.top, 24)
                
                Image("DevoLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .padding(.top, 8)
                
                Text("Inicia sesión")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.primaryText)
                    .padding(.top, 4)
                
                // Email
                VStack(spacing: 12) {
                    AppTextField(
                        text: $email,
                        placeholder: "Ingresa Tu Email",
                        keyboard: .emailAddress
                    )
                    
                    // Password con mostrar/ocultar
                    PasswordField(
                        password: $password,
                        showPassword: $showPassword,
                        placeholder: "Contraseña"
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 6)
                
                // ---- Divider con texto
                DividerWithText(text: "Continuar con")
                    .padding(.horizontal, 24)
                    .padding(.top, 6)
                
                // Botón Facebook
                SocialButton(
                    title: "Login with Facebook",
                    background: Color.facebookBlue,
                    foreground: .white,
                    borderOnly: false,
                    icon: Image("facebook")
                ) {
                    // TODO: acción Facebook
                }
                .padding(.horizontal, 24)
                
                // Botón Google (borde gris)
                SocialButton(
                    title: "Login with Google",
                    background: .clear,
                    foreground: Color.primaryText,
                    borderOnly: true,
                    icon: Image("Google")
                ) {
                    // TODO: acción Google
                }
                .padding(.horizontal, 24)
                
                // Registro
                HStack(spacing: 6) {
                    Text("¿No tienes cuenta?")
                        .foregroundStyle(Color.secondaryText)
                    Button("Regístrate") {
                        // TODO: navegar a registro
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentBrand)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color.screenBG.ignoresSafeArea())
    }
}

// MARK: - Subviews

private struct AppTextField: View {
    @Binding var text: String
    let placeholder: String
    var keyboard: UIKeyboardType = .default
    
    var body: some View {
        TextField(placeholder, text: $text)
            .textInputAutocapitalization(.never)
            .keyboardType(keyboard)
            .autocorrectionDisabled(true)
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.inputBorder, lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.inputBG))
            )
            .foregroundStyle(Color.primaryText)
    }
}

private struct PasswordField: View {
    @Binding var password: String
    @Binding var showPassword: Bool
    let placeholder: String
    
    var body: some View {
        HStack(spacing: 0) {
            Group {
                if showPassword {
                    TextField(placeholder, text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                } else {
                    SecureField(placeholder, text: $password)
                }
            }
            .foregroundStyle(Color.primaryText)
            
            Button {
                withAnimation { showPassword.toggle() }
            } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .imageScale(.medium)
                    .foregroundStyle(Color.secondaryText)
            }
            .padding(.trailing, 2)
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.inputBorder, lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.inputBG))
        )
    }
}

private struct DividerWithText: View {
    let text: String
    var body: some View {
        HStack {
            line
            Text(text)
                .font(.callout)
                .foregroundStyle(Color.secondaryText)
            line
        }
    }
    private var line: some View {
        Rectangle()
            .fill(Color.divider)
            .frame(height: 1)
    }
}

private struct SocialButton: View {
    let title: String
    let background: Color
    let foreground: Color
    let borderOnly: Bool
    let icon: Image?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon {
                    icon
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                }
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 16)
            .frame(height: 52)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if borderOnly {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.inputBorder, lineWidth: 1)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(background)
                    }
                }
            )
        }
    }
}

// Tema

private extension Color {
    static let screenBG      = Color.white
    static let primaryText   = Color.black.opacity(0.85)
    static let secondaryText = Color.black.opacity(0.55)
    static let inputBG       = Color.white
    static let inputBorder   = Color.gray.opacity(0.35)
    static let divider       = Color.gray.opacity(0.35)
    static let facebookBlue  = Color(red: 59/255, green: 89/255, blue: 152/255)
    static let accentBrand   = Color(red: 0.12, green: 0.47, blue: 0.95) // para "Regístrate"
}

// MARK: - Preview

#Preview {
    LoginView()
}
