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
        // Asegurar que el TabBar esté siempre visible
        .toolbar(.visible, for: .tabBar)
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
    @EnvironmentObject var teamManager: TeamManager
    @State private var userInfo: UserInfo?
    @State private var isLoading = true
    @State private var showSignOutAlert = false
    @State private var allowPaste = true
    @State private var activateReminder = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header con nombre del equipo (si tiene equipo)
                    if let team = teamManager.currentTeam {
                        HStack(spacing: 12) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.accentBrand)
                            Text(team.name)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.primaryText)
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color.gray.opacity(0.1))
                    }
                    
                    if isLoading {
                        ProgressView()
                            .padding()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        VStack(spacing: 24) {
                            // Avatar y información del usuario
                            VStack(spacing: 16) {
                                // Avatar circular azul
                                Circle()
                                    .fill(Color(red: 0.2, green: 0.4, blue: 0.8))
                                    .frame(width: 80, height: 80)
                                    .overlay {
                                        Text(avatarInitials)
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                
                                // Nombre
                                Text(userInfo?.displayName ?? NSLocalizedString("user", comment: ""))
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(Color.primaryText)
                                
                                // Email
                                if let email = userInfo?.email {
                                    Text(email)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.secondaryText)
                                }
                            }
                            .padding(.top, 24)
                            
                            // Menú de opciones
                            VStack(spacing: 0) {
                                // Ver mis equipos
                                NavigationLink {
                                    MainTeamView()
                                        .environmentObject(authManager)
                                        .environmentObject(teamManager)
                                        // TabBar visible - pantalla principal
                                } label: {
                                    MenuRowContent(
                                        title: NSLocalizedString("view_my_teams", comment: ""),
                                        icon: "person.3.fill",
                                        showChevron: true
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Divider().padding(.leading, 60)
                                
                                // Cambiar contraseña
                                NavigationLink {
                                    ChangePasswordView()
                                        .toolbar(.hidden, for: .tabBar) // Ocultar TabBar en configuración
                                } label: {
                                    MenuRowContent(
                                        title: NSLocalizedString("change_password", comment: ""),
                                        icon: "lock.fill",
                                        showChevron: true
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Divider().padding(.leading, 60)
                                
                                // Crear equipo
                                NavigationLink {
                                    TeamSelectionView()
                                        .environmentObject(authManager)
                                        // TabBar visible - pantalla principal de selección
                                } label: {
                                    MenuRowContent(
                                        title: NSLocalizedString("create_team", comment: ""),
                                        icon: "plus.circle.fill",
                                        showChevron: true
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Divider().padding(.leading, 60)
                                
                                // Permitir pegar
                                ToggleRow(
                                    title: NSLocalizedString("allow_paste", comment: ""),
                                    icon: "doc.on.clipboard.fill",
                                    isOn: $allowPaste
                                )
                                
                                Divider().padding(.leading, 60)
                                
                                // Activar recordatorio
                                ToggleRow(
                                    title: NSLocalizedString("activate_reminder", comment: ""),
                                    icon: "bell.fill",
                                    isOn: $activateReminder
                                )
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            
                            Spacer()
                        }
                    }
                }
            }
            .background(Color.screenBG.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .tabBar) // Asegurar que TabBar esté visible al regresar
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

// MARK: - Menu Row

struct MenuRow: View {
    let title: String
    let icon: String
    let showChevron: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            MenuRowContent(title: title, icon: icon, showChevron: showChevron)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Menu Row Content (reutilizable)

struct MenuRowContent: View {
    let title: String
    let icon: String
    let showChevron: Bool
    
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
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondaryText)
            }
        }
        .padding(16)
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

