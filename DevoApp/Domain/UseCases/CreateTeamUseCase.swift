import Foundation
import FirebaseAuth

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
        // Validación de seguridad: verificar que el usuario esté autenticado
        guard let currentUser = Auth.auth().currentUser else {
            throw TeamError.userNotAuthenticated
        }
        
        // Validación de seguridad: verificar que el leaderId coincida con el usuario autenticado
        guard leaderId == currentUser.uid else {
            throw TeamError.userNotAuthenticated
        }
        
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
        
        // Crear el equipo y actualizar perfil del usuario
        let team = try await teamRepository.createTeam(
            name: trimmedName,
            leaderId: leaderId,
            leaderName: leaderName
        )
        
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

