import Foundation

// MARK: - User Entity (Domain Layer)

struct UserEntity: Identifiable, Equatable {
    let id: String
    let email: String
    let displayName: String?
    let firstName: String?
    let lastName: String?
    let teamId: String? // Mantener para compatibilidad hacia atrás
    let role: UserRole? // Mantener para compatibilidad hacia atrás
    let teams: [UserTeam] // Nuevo: array de equipos
    let selectedTeamId: String? // Equipo activo/seleccionado
    let createdAt: Date?
    let updatedAt: Date?
    
    // Inicializador con compatibilidad hacia atrás
    init(
        id: String,
        email: String,
        displayName: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        teamId: String? = nil,
        role: UserRole? = nil,
        teams: [UserTeam] = [],
        selectedTeamId: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.firstName = firstName
        self.lastName = lastName
        self.teamId = teamId
        self.role = role
        // Si hay teamId pero no teams, crear UserTeam para compatibilidad
        var userTeams = teams
        if let teamId = teamId, userTeams.isEmpty, let role = role {
            userTeams = [UserTeam(teamId: teamId, role: role, joinedAt: createdAt ?? Date())]
        }
        self.teams = userTeams
        // Si hay selectedTeamId, usarlo; si no, usar el primer equipo o teamId
        self.selectedTeamId = selectedTeamId ?? userTeams.first?.teamId ?? teamId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - User Team

struct UserTeam: Identifiable, Equatable, Codable {
    let id: String // teamId
    let teamId: String
    let role: UserRole
    let joinedAt: Date
    
    init(teamId: String, role: UserRole, joinedAt: Date = Date()) {
        self.id = teamId
        self.teamId = teamId
        self.role = role
        self.joinedAt = joinedAt
    }
}

enum UserRole: String, Codable {
    case leader
    case member
}

