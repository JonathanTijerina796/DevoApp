import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var teamManager: TeamManager
    @Environment(\.dismiss) var dismiss
    @State private var userInfo: UserInfo?
    @State private var isLoading = true
    @State private var showSignOutAlert = false
    @State private var reminderEnabled = true
    @State private var allowPaste = true
    @State private var showMyTeams = false
    @State private var showChangePassword = false
    
    private var isLeader: Bool {
        userInfo?.role == "leader"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        // Header con avatar
                        VStack(spacing: 16) {
                            // Avatar
                            Circle()
                                .fill(Color(red: 0.2, green: 0.4, blue: 0.8))
                                .frame(width: 100, height: 100)
                                .overlay {
                                    Text(avatarInitials)
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            
                            // Nombre
                            Text(userInfo?.displayName ?? NSLocalizedString("user", comment: ""))
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(Color.primaryText)
                            
                            // Email
                            if let email = userInfo?.email {
                                Text(email)
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.secondaryText)
                            }
                        }
                        .padding(.top, 32)
                        .padding(.horizontal, 24)
                        
                        // Menú de opciones
                        VStack(spacing: 0) {
                            // Ver mis equipos
                            MenuRow(
                                title: NSLocalizedString("view_my_teams", comment: ""),
                                icon: "person.3.fill",
                                showChevron: true
                            ) {
                                showMyTeams = true
                            }
                            
                            Divider()
                                .padding(.leading, 60)
                            
                            // Cambiar contraseña
                            MenuRow(
                                title: NSLocalizedString("change_password", comment: ""),
                                icon: "lock.fill",
                                showChevron: true
                            ) {
                                showChangePassword = true
                            }
                            
                            Divider()
                                .padding(.leading, 60)
                            
                            // Activar recordatorio
                            ToggleRow(
                                title: NSLocalizedString("activate_reminder", comment: ""),
                                icon: "bell.fill",
                                isOn: $reminderEnabled
                            )
                            
                            Divider()
                                .padding(.leading, 60)
                            
                            // Permitir pegar
                            ToggleRow(
                                title: NSLocalizedString("allow_paste", comment: ""),
                                icon: "doc.on.clipboard.fill",
                                isOn: $allowPaste
                            )
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 24)
                        .padding(.top, 32)
                        
                        // Botón Agregar nuevo integrante (solo para líderes)
                        if isLeader {
                            Button {
                                showMyTeams = true
                            } label: {
                                Text(NSLocalizedString("add_new_member", comment: ""))
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(Color.green)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                        }
                        
                        // Botón de cerrar sesión
                        Button {
                            showSignOutAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text(NSLocalizedString("sign_out", comment: ""))
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.red)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(Color.screenBG.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("my_profile", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("done", comment: "")) {
                        dismiss()
                    }
                    .foregroundStyle(Color.accentBrand)
                }
            }
            .task {
                await loadUserInfo()
            }
            .alert(NSLocalizedString("sign_out", comment: ""), isPresented: $showSignOutAlert) {
                Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { }
                Button(NSLocalizedString("sign_out", comment: ""), role: .destructive) {
                    authManager.signOut()
                }
            } message: {
                Text(NSLocalizedString("sign_out_confirmation", comment: ""))
            }
            .sheet(isPresented: $showMyTeams) {
                MainTeamView()
                    .environmentObject(authManager)
                    .environmentObject(teamManager)
            }
        }
    }
    
    private var avatarInitials: String {
        guard let displayName = userInfo?.displayName ?? authManager.user?.displayName else {
            return authManager.user?.email?.prefix(1).uppercased() ?? "U"
        }
        let components = displayName.components(separatedBy: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else {
            return String(displayName.prefix(2)).uppercased()
        }
    }
    
    private func loadUserInfo() async {
        guard let user = authManager.user else {
            isLoading = false
            return
        }
        
        isLoading = true
        
        do {
            let userDoc = try await Firestore.firestore()
                .collection("users")
                .document(user.uid)
                .getDocument()
            
            if let data = userDoc.data() {
                userInfo = UserInfo(
                    displayName: data["displayName"] as? String ?? user.displayName ?? user.email ?? "",
                    email: data["email"] as? String ?? user.email ?? "",
                    role: data["role"] as? String,
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
                )
            } else {
                // Si no hay datos en Firestore, usar datos de Auth
                userInfo = UserInfo(
                    displayName: user.displayName ?? user.email ?? "",
                    email: user.email ?? "",
                    role: nil,
                    createdAt: nil
                )
            }
            
            isLoading = false
        } catch {
            print("Error loading user info: \(error)")
            // Fallback a datos de Auth
            userInfo = UserInfo(
                displayName: user.displayName ?? user.email ?? "",
                email: user.email ?? "",
                role: nil,
                createdAt: nil
            )
            isLoading = false
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
}

// MARK: - Menu Row

struct MenuRow: View {
    let title: String
    let icon: String
    let showChevron: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.accentBrand)
                    .frame(width: 30)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.primaryText)
                
                Spacer()
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.secondaryText)
                }
            }
            .padding(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Toggle Row

struct ToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Color.accentBrand)
                .frame(width: 30)
            
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Color.primaryText)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(.green)
        }
        .padding(16)
    }
}

// MARK: - User Info Model

struct UserInfo {
    let displayName: String
    let email: String
    let role: String?
    let createdAt: Date?
}

