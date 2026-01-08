import SwiftUI
import FirebaseFirestore

// MARK: - Main Tab View
// TabBar principal de navegación entre Home y Perfil

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var teamManager: TeamManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Home
            HomeTabView()
                .tabItem {
                    Label(
                        NSLocalizedString("home", comment: ""),
                        systemImage: selectedTab == 0 ? "house.fill" : "house"
                    )
                }
                .tag(0)
            
            // Tab 2: Perfil
            ProfileTabView()
                .tabItem {
                    Label(
                        NSLocalizedString("profile", comment: ""),
                        systemImage: selectedTab == 1 ? "person.fill" : "person"
                    )
                }
                .tag(1)
        }
        .accentColor(Color.accentBrand)
    }
}

// MARK: - Home Tab View

struct HomeTabView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var teamManager: TeamManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header de bienvenida
                    WelcomeHeaderView()
                        .padding(.top, 20)
                    
                    // Si tiene equipo, mostrar información del equipo
                    if let team = teamManager.currentTeam {
                        TeamInfoCard(team: team)
                            .padding(.horizontal, 24)
                        
                        // Acciones rápidas
                        QuickActionsView(team: team)
                            .padding(.horizontal, 24)
                    } else {
                        // Si no tiene equipo, mostrar opción para unirse
                        NoTeamCard()
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color.screenBG.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("home", comment: ""))
        }
    }
}

// MARK: - Profile Tab View

struct ProfileTabView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var userInfo: UserInfo?
    @State private var isLoading = true
    @State private var showSignOutAlert = false
    
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
                                .fill(Color.accentBrand)
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
                        
                        // Información del usuario
                        VStack(spacing: 16) {
                            // Rol en el equipo
                            if let role = userInfo?.role {
                                InfoRow(
                                    icon: "person.fill",
                                    title: NSLocalizedString("role", comment: ""),
                                    value: role == "leader" ? NSLocalizedString("leader", comment: "") : NSLocalizedString("member", comment: "")
                                )
                            }
                            
                            // Fecha de registro
                            if let createdAt = userInfo?.createdAt {
                                InfoRow(
                                    icon: "calendar",
                                    title: NSLocalizedString("member_since", comment: ""),
                                    value: formatDate(createdAt)
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 32)
                        
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
                        .padding(.top, 32)
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(Color.screenBG.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("profile", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
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

