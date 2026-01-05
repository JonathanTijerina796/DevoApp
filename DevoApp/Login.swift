import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    // Login
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword = false
    
    // Modo registro (campos extras)
    @State private var isSignUp = false
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var confirmPassword: String = ""
    @State private var showConfirmPassword = false
    @State private var showAlert = false

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
                
                // Título cambia según modo
                Text(isSignUp ? NSLocalizedString("create_account", comment: "") : NSLocalizedString("sign_in", comment: ""))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.primaryText)
                    .padding(.top, 4)
                
                // Campos
                VStack(spacing: 12) {
                    // NUEVO: Nombre / Apellido solo en registro
                    if isSignUp {
                        AppTextField(
                            text: $firstName,
                            placeholder: NSLocalizedString("first_name", comment: "")
                        )
                        AppTextField(
                            text: $lastName,
                            placeholder: NSLocalizedString("last_name", comment: "")
                        )
                    }
                    
                    AppTextField(
                        text: $email,
                        placeholder: NSLocalizedString("enter_email", comment: ""),
                        keyboard: .emailAddress
                    )
                    
                    PasswordField(
                        password: $password,
                        showPassword: $showPassword,
                        placeholder: NSLocalizedString("password", comment: "")
                    )
                    
                    // NUEVO: Confirmar contraseña solo en registro
                    if isSignUp {
                        PasswordField(
                            password: $confirmPassword,
                            showPassword: $showConfirmPassword,
                            placeholder: NSLocalizedString("confirm_password", comment: "")
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 6)
                
                // Botón principal de acción
                Button {
                    Task {
                        if isSignUp {
                            await handleSignUp()
                        } else {
                            await handleSignIn()
                        }
                    }
                } label: {
                    HStack {
                        if authManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        }
                        Text(isSignUp ? NSLocalizedString("create_account", comment: "") : NSLocalizedString("sign_in", comment: ""))
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.accentBrand)
                    .cornerRadius(12)
                }
                .disabled(authManager.isLoading)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                // ---- Divider con textos
                DividerWithText(text: NSLocalizedString("or_continue_with", comment: ""))
                    .padding(.horizontal, 15)
                    .padding(.top, 16)
                
                // Botón Facebook
                SocialButton(
                    title: NSLocalizedString("login_facebook", comment: ""),
                    background: Color.facebookBlue,
                    foreground: .white,
                    borderOnly: false,
                    icon: Image("facebook")
                ) {
                    Task {
                        let success = await authManager.signInWithFacebook()
                        if !success || !authManager.errorMessage.isEmpty {
                            showAlert = true
                        }
                    }
                }
                .disabled(authManager.isLoading)
                .padding(.horizontal, 24)
                
                // Botón Google
                SocialButton(
                    title: NSLocalizedString("login_google", comment: ""),
                    background: .clear,
                    foreground: Color.primaryText,
                    borderOnly: true,
                    icon: Image("Google")
                ) {
                    Task {
                        let success = await authManager.signInWithGoogle()
                        if !success || !authManager.errorMessage.isEmpty {
                            showAlert = true
                        }
                    }
                }
                .disabled(authManager.isLoading)
                .padding(.horizontal, 24)
                
                // Registro / Toggle de modo
                HStack(spacing: 6) {
                    Text(NSLocalizedString("no_account", comment: ""))
                        .foregroundStyle(Color.secondaryText)
                    
                    Button(isSignUp ? NSLocalizedString("login", comment: "") : NSLocalizedString("sign_up", comment: "")) {
                        // Cambia entre login y registro en la misma pantalla
                        withAnimation { isSignUp.toggle() }
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
        .alert("Error", isPresented: $showAlert) {
            Button("OK") { 
                authManager.errorMessage = ""
            }
        } message: {
            Text(authManager.errorMessage)
        }
    }
    
    // MARK: - Authentication Methods
    
    private func handleSignUp() async {
        guard password == confirmPassword else {
            authManager.errorMessage = NSLocalizedString("passwords_dont_match", comment: "")
            showAlert = true
            return
        }
        
        let success = await authManager.signUp(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName
        )
        
        if !success {
            showAlert = true
        }
    }
    
    private func handleSignIn() async {
        let success = await authManager.signIn(email: email, password: password)
        
        if !success {
            showAlert = true
        }
    }
}

 //Subviews

struct AppTextField: View {
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
                RoundedRectangle(cornerRadius:12)
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
            RoundedRectangle(cornerRadius:12)
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

extension Color {
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

#if DEBUG
// Mock AuthenticationManager para Preview (sin Firebase)
class MockAuthenticationManager: ObservableObject {
    @Published var user: User? = nil
    @Published var isSignedIn = false
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    func signUp(email: String, password: String, firstName: String, lastName: String) async -> Bool {
        print("🎨 Preview Mock - SignUp called")
        return true
    }
    
    func signIn(email: String, password: String) async -> Bool {
        print("🎨 Preview Mock - SignIn called")
        return true
    }
    
    func signInWithGoogle() async -> Bool {
        print("🎨 Preview Mock - Google SignIn called")
        return true
    }
    
    func signInWithFacebook() async -> Bool {
        print("🎨 Preview Mock - Facebook SignIn called")
        return true
    }
    
    func signOut() {
        print("🎨 Preview Mock - SignOut called")
    }
}
#endif

#Preview {
    LoginView()
        .environmentObject(MockAuthenticationManager())
}
