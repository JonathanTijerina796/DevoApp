import SwiftUI
import FirebaseAuth

struct HomeView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var teamManager: TeamManager
    @State private var showTeamSelector = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header de bienvenida
                WelcomeHeaderView()
                    .padding(.top, 20)
                
                // Si tiene equipo, mostrar devocional
                if let team = teamManager.currentTeam, let teamId = team.id {
                    // Header con nombre del equipo y flecha desplegable
                    TeamHeaderWithSelector(team: team) {
                        showTeamSelector = true
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    
                    // Vista de devocional (ocupa el resto del espacio)
                    DevotionalView(
                        teamId: teamId,
                        viewModel: DependencyContainer.shared.makeDevotionalViewModel()
                    )
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
            .navigationTitle(NSLocalizedString("home", comment: ""))
            .sheet(isPresented: $showTeamSelector) {
                TeamSelectorView { teamId in
                    Task {
                        await teamManager.switchTeam(teamId: teamId)
                    }
                }
                .environmentObject(teamManager)
            }
        }
    }
}

// MARK: - Welcome Header

struct WelcomeHeaderView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        VStack(spacing: 12) {
            Text(NSLocalizedString("welcome_back", comment: ""))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.primaryText)
            
            if let user = authManager.user {
                Text(user.displayName ?? user.email ?? NSLocalizedString("user", comment: ""))
                    .font(.system(size: 20))
                    .foregroundStyle(Color.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Team Info Card

struct TeamInfoCard: View {
    let team: Team
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.accentBrand)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(team.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.primaryText)
                    
                    Text("\(NSLocalizedString("code", comment: "")): \(team.code)")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondaryText)
                }
                
                Spacer()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
            )
        }
    }
}

// MARK: - Quick Actions

struct QuickActionsView: View {
    let team: Team
    @EnvironmentObject var teamManager: TeamManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("quick_actions", comment: ""))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.primaryText)
                .padding(.horizontal, 4)
            
            NavigationLink {
                MainTeamView()
                    .environmentObject(authManager)
                    .environmentObject(teamManager)
            } label: {
                HStack {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 20))
                    Text(NSLocalizedString("view_team", comment: ""))
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                }
                .foregroundStyle(Color.primaryText)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
            }
        }
    }
}

// MARK: - No Team Card

struct NoTeamCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 50))
                .foregroundStyle(Color.secondaryText)
            
            Text(NSLocalizedString("no_team_yet", comment: ""))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.primaryText)
            
            Text(NSLocalizedString("join_or_create_team", comment: ""))
                .font(.system(size: 14))
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

