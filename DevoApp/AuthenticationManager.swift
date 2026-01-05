import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
// import FBSDKLoginKit // Temporalmente deshabilitado

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var user: User?
    @Published var isSignedIn = false
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        listenToAuthState()
    }
    
    deinit {
        if let handle = authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    private func listenToAuthState() {
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.isSignedIn = user != nil
            }
        }
    }
    
    // MARK: - Email/Password Authentication
    
    func signUp(email: String, password: String, firstName: String, lastName: String) async -> Bool {
        guard !email.isEmpty, !password.isEmpty, !firstName.isEmpty, !lastName.isEmpty else {
            errorMessage = NSLocalizedString("all_fields_required", comment: "")
            return false
        }
        
        guard isValidEmail(email) else {
            errorMessage = NSLocalizedString("invalid_email", comment: "")
            return false
        }
        
        guard password.count >= 6 else {
            errorMessage = NSLocalizedString("password_min_length", comment: "")
            return false
        }
        
        isLoading = true
        errorMessage = ""
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Actualizar perfil con nombre
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = "\(firstName) \(lastName)"
            try await changeRequest.commitChanges()
            
            isLoading = false
            return true
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func signIn(email: String, password: String) async -> Bool {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = NSLocalizedString("email_password_required", comment: "")
            return false
        }
        
        isLoading = true
        errorMessage = ""
        
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
            isLoading = false
            return true
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle() async -> Bool {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = NSLocalizedString("google_config_error", comment: "")
            return false
        }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = NSLocalizedString("view_controller_error", comment: "")
            return false
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        isLoading = true
        errorMessage = ""
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = NSLocalizedString("google_token_error", comment: "")
                isLoading = false
                return false
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            
            try await Auth.auth().signIn(with: credential)
            isLoading = false
            return true
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Facebook Sign In (Temporalmente deshabilitado)
    
    func signInWithFacebook() async -> Bool {
        // Facebook login temporalmente deshabilitado
        errorMessage = "Facebook login no disponible temporalmente"
        return false
    }
    
    /*
    func signInWithFacebook() async -> Bool {
        let loginManager = LoginManager()
        
        isLoading = true
        errorMessage = ""
        
        return await withCheckedContinuation { continuation in
            loginManager.logIn(permissions: ["email"], from: nil) { [weak self] result, error in
                Task { @MainActor in
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        self?.isLoading = false
                        continuation.resume(returning: false)
                        return
                    }
                    
                    guard let result = result, !result.isCancelled else {
                        self?.errorMessage = NSLocalizedString("login_cancelled", comment: "")
                        self?.isLoading = false
                        continuation.resume(returning: false)
                        return
                    }
                    
                    guard let token = result.token?.tokenString else {
                        self?.errorMessage = NSLocalizedString("facebook_token_error", comment: "")
                        self?.isLoading = false
                        continuation.resume(returning: false)
                        return
                    }
                    
                    let credential = FacebookAuthProvider.credential(withAccessToken: token)
                    
                    do {
                        try await Auth.auth().signIn(with: credential)
                        self?.isLoading = false
                        continuation.resume(returning: true)
                    } catch {
                        self?.errorMessage = error.localizedDescription
                        self?.isLoading = false
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
    */
    
    // MARK: - Sign Out
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            // LoginManager().logOut() // Temporalmente deshabilitado
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Helper Methods
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}
