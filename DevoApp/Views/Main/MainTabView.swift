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
        .onChange(of: teamManager.currentTeam) { oldValue, newValue in
            // Si cambió de un equipo a otro (no de nil a equipo), asegurar que estemos en Home
            if oldValue != nil && newValue != nil && oldValue?.id != newValue?.id {
                print("🔄 [MainTabView] Equipo cambió de \(oldValue?.name ?? "nil") a \(newValue?.name ?? "nil"), navegando a Home...")
                withAnimation {
                    selectedTab = 0
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TeamCreated"))) { _ in
            // Cuando se crea un equipo, navegar automáticamente al Home
            print("📢 [MainTabView] Equipo creado, navegando a Home...")
            withAnimation {
                selectedTab = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TeamJoined"))) { _ in
            // Cuando se une a un equipo, navegar automáticamente al Home
            print("📢 [MainTabView] Equipo unido, navegando a Home...")
            withAnimation {
                selectedTab = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TeamDeleted"))) { _ in
            // Cuando se elimina un equipo, navegar automáticamente al Home
            // Esto asegura que si hay otros equipos, se muestre el Home con el nuevo equipo
            print("📢 [MainTabView] Equipo eliminado, navegando a Home...")
            // Esperar a que loadAllUserTeams() termine y actualice currentTeam
            Task {
                // Esperar un poco para que loadAllUserTeams() complete
                var attempts = 0
                while teamManager.isLoading && attempts < 10 {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 segundos
                    attempts += 1
                }
                // Esperar un poco más para asegurar que currentTeam se haya actualizado
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 segundos adicionales
                await MainActor.run {
                    print("✅ [MainTabView] Navegando a Home. currentTeam: \(teamManager.currentTeam?.name ?? "ninguno")")
                    withAnimation {
                        selectedTab = 0
                    }
                }
            }
        }
    }
}

// MARK: - Home Tab View

struct HomeTabView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var teamManager: TeamManager
    @State private var showTeamSelector = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Mostrar loading mientras se cargan los equipos
                if teamManager.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                // Si tiene equipo, mostrar devocional
                else if let team = teamManager.currentTeam, let teamId = team.id {
                    // Header con nombre del equipo y flecha desplegable (arriba)
                    TeamHeaderWithSelector(team: team) {
                        showTeamSelector = true
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    
                    // Vista de devocional (ocupa el resto del espacio)
                    // Usar .id() para forzar recreación cuando cambia el equipo
                    DevotionalView(
                        teamId: teamId,
                        viewModel: DependencyContainer.shared.makeDevotionalViewModel()
                    )
                    .id(teamId) // Forzar recreación cuando cambia el teamId
                } else {
                    // Si no tiene equipo, mostrar opción para unirse
                    ScrollView {
                        NoTeamCard()
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                    }
                }
            }
            .background(Color.screenBG.ignoresSafeArea())
            .sheet(isPresented: $showTeamSelector) {
                TeamSelectorView { teamId in
                    Task {
                        await teamManager.switchTeam(teamId: teamId)
                    }
                }
                .environmentObject(teamManager)
            }
        }
        .navigationBarHidden(true)
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
    @State private var showTeamSelection = false
    
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
                                Button {
                                    showTeamSelection = true
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
                            
                            // Botón de cerrar sesión
                            Button {
                                showSignOutAlert = true
                            } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 20))
                                        .foregroundStyle(Color.red)
                                        .frame(width: 30)
                                    
                                    Text(NSLocalizedString("sign_out", comment: ""))
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color.red)
                                    
                                    Spacer()
                                }
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(12)
                            }
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
            .sheet(isPresented: $showTeamSelection) {
                TeamSelectionView()
                    .environmentObject(authManager)
                    .environmentObject(teamManager)
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TeamCreated"))) { _ in
                        // Cerrar el modal cuando se crea el equipo
                        showTeamSelection = false
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TeamJoined"))) { _ in
                        // Cerrar el modal cuando se une a un equipo
                        showTeamSelection = false
                    }
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

// MARK: - Team Header With Selector

struct TeamHeaderWithSelector: View {
    let team: Team
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.accentBrand)
                
                Text(team.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.primaryText)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
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

