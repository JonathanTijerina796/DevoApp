import Foundation

// MARK: - Create Team Use Case
// Single Responsibility Principle: Una sola responsabilidad - crear un equipo

protocol CreateTeamUseCaseProtocol {
    func execute(name: String, leaderId: String, leaderName: String) async throws -> TeamEntity
}

final class CreateTeamUseCase: CreateTeamUseCaseProtocol {
    private let teamRepository: TeamRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    
    // Dependency Injection
    init(teamRepository: TeamRepositoryProtocol, userRepository: UserRepositoryProtocol) {
        self.teamRepository = teamRepository
        self.userRepository = userRepository
    }
    
    func execute(name: String, leaderId: String, leaderName: String) async throws -> TeamEntity {
        // Validaciones de negocio
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else {
            throw TeamError.teamNameRequired
        }
        
        guard trimmedName.count <= 50 else {
            throw TeamError.teamNameTooLong
        }
        
        // Verificar que el usuario no tenga ya un equipo
        if let existingTeamId = try? await userRepository.getUserTeamId(leaderId),
           !existingTeamId.isEmpty {
            throw TeamError.userAlreadyInTeam
        }
        
        // Generar código único
        let code = try await teamRepository.generateUniqueTeamCode()
        
        // Crear el equipo
        let team = try await teamRepository.createTeam(
            name: trimmedName,
            leaderId: leaderId,
            leaderName: leaderName
        )
        
        // Actualizar el perfil del usuario
        try await userRepository.setUserTeam(
            userId: leaderId,
            teamId: team.id ?? "",
            role: .leader
        )
        
        return team
    }
}

// MARK: - Team Errors

enum TeamError: LocalizedError {
    case teamNameRequired
    case teamNameTooLong
    case userAlreadyInTeam
    case teamNotFound
    case userNotAuthenticated
    case alreadyTeamLeader
    case alreadyTeamMember
    case invalidTeamCode
    
    var errorDescription: String? {
        switch self {
        case .teamNameRequired:
            return NSLocalizedString("team_name_required", comment: "")
        case .teamNameTooLong:
            return "El nombre del equipo no puede tener más de 50 caracteres"
        case .userAlreadyInTeam:
            return "Ya perteneces a un equipo. Debes salir del equipo actual antes de crear uno nuevo."
        case .teamNotFound:
            return NSLocalizedString("team_not_found", comment: "")
        case .userNotAuthenticated:
            return NSLocalizedString("user_not_authenticated", comment: "")
        case .alreadyTeamLeader:
            return NSLocalizedString("already_team_leader", comment: "")
        case .alreadyTeamMember:
            return NSLocalizedString("already_team_member", comment: "")
        case .invalidTeamCode:
            return NSLocalizedString("team_code_required", comment: "")
        }
    }
}

