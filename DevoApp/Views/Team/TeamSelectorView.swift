import SwiftUI
import FirebaseFirestore

// MARK: - Team Selector View
// Bottom sheet para seleccionar entre los equipos del usuario

struct TeamSelectorView: View {
    @EnvironmentObject var teamManager: TeamManager
    @Environment(\.dismiss) var dismiss
    @State private var teams: [TeamWithLeader] = []
    @State private var isLoading = true
    
    let onSelectTeam: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text(NSLocalizedString("teams", comment: ""))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.primaryText)
                    
                    Text(NSLocalizedString("select_team_to_work", comment: ""))
                        .font(.system(size: 14))
                        .foregroundStyle(Color.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                
                // Lista de equipos
                if isLoading {
                    ProgressView()
                        .padding()
                        .frame(maxWidth: .infinity)
                } else if teams.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(Color.secondaryText)
                        Text(NSLocalizedString("no_teams_available", comment: ""))
                            .font(.system(size: 16))
                            .foregroundStyle(Color.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(teams) { team in
                                TeamRow(
                                    team: team,
                                    isSelected: teamManager.currentTeam?.id == team.id,
                                    onSelect: {
                                        onSelectTeam(team.id ?? "")
                                        dismiss()
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                }
                
                Spacer()
                
                // Botones de acción
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Text(NSLocalizedString("cancel", comment: ""))
                            .font(.headline)
                            .foregroundColor(Color.accentBrand)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.accentBrand, lineWidth: 2)
                            )
                    }
                    
                    Button {
                        if let selectedTeam = teams.first(where: { $0.id == teamManager.currentTeam?.id }),
                           let teamId = selectedTeam.id {
                            onSelectTeam(teamId)
                            dismiss()
                        }
                    } label: {
                        Text(NSLocalizedString("change_team", comment: ""))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.accentBrand)
                            .cornerRadius(12)
                    }
                    .disabled(teams.isEmpty)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(Color.screenBG.ignoresSafeArea())
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
                await loadTeams()
            }
        }
    }
    
    private func loadTeams() async {
        isLoading = true
        
        var loadedTeams: [TeamWithLeader] = []
        
        for team in teamManager.allTeams {
            // Cargar información del líder
            var leaderEmail = ""
            if let leaderDoc = try? await Firestore.firestore()
                .collection("users")
                .document(team.leaderId)
                .getDocument(),
               let data = leaderDoc.data(),
               let email = data["email"] as? String {
                leaderEmail = email
            }
            
            loadedTeams.append(TeamWithLeader(
                id: team.id,
                name: team.name,
                code: team.code,
                leaderId: team.leaderId,
                leaderName: team.leaderName,
                leaderEmail: leaderEmail,
                memberIds: team.memberIds,
                createdAt: team.createdAt,
                updatedAt: team.updatedAt
            ))
        }
        
        teams = loadedTeams
        isLoading = false
    }
}

// MARK: - Team With Leader

struct TeamWithLeader: Identifiable {
    let id: String?
    let name: String
    let code: String
    let leaderId: String
    let leaderName: String
    let leaderEmail: String
    let memberIds: [String]
    let createdAt: Timestamp
    let updatedAt: Timestamp
}

// MARK: - Team Row

struct TeamRow: View {
    let team: TeamWithLeader
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Avatar circular con color
                Circle()
                    .fill(avatarColor)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Text(String(team.name.prefix(1)).uppercased())
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                
                // Información del equipo
                VStack(alignment: .leading, spacing: 4) {
                    Text(team.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primaryText)
                    
                    Text(team.leaderEmail)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.secondaryText)
                }
                
                Spacer()
                
                // Indicador de selección
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.accentBrand)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentBrand.opacity(0.1) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var avatarColor: Color {
        // Generar color basado en el nombre del equipo para consistencia
        let colors: [Color] = [
            Color(red: 0.2, green: 0.4, blue: 0.8), // Azul
            Color(red: 0.8, green: 0.3, blue: 0.5), // Rosa
            Color(red: 0.3, green: 0.6, blue: 0.4), // Verde
            Color(red: 0.9, green: 0.6, blue: 0.2), // Naranja
            Color(red: 0.5, green: 0.3, blue: 0.7), // Morado
        ]
        let index = abs(team.name.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - Preview

#Preview {
    TeamSelectorView(onSelectTeam: { _ in })
        .environmentObject(TeamManager())
}
