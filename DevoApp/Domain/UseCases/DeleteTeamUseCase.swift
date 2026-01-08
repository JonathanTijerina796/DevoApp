import Foundation

// MARK: - Delete Team Use Case
// Single Responsibility Principle: Una sola responsabilidad - eliminar un equipo

protocol DeleteTeamUseCaseProtocol {
    func execute(teamId: String, leaderId: String) async throws
}

final class DeleteTeamUseCase: DeleteTeamUseCaseProtocol {
    private let teamRepository: TeamRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    
    init(teamRepository: TeamRepositoryProtocol, userRepository: UserRepositoryProtocol) {
        self.teamRepository = teamRepository
        self.userRepository = userRepository
    }
    
    func execute(teamId: String, leaderId: String) async throws {
        // Verificar que el equipo existe
        guard let team = try await teamRepository.getTeamById(teamId) else {
            throw TeamError.teamNotFound
        }
        
        // Verificar que el usuario es el líder
        guard team.leaderId == leaderId else {
            throw TeamError.alreadyTeamLeader
        }
        
        // Obtener todos los miembros (incluyendo el líder)
        var allMemberIds = team.memberIds
        allMemberIds.append(team.leaderId)
        
        // Eliminar referencias del equipo en todos los usuarios
        for memberId in allMemberIds {
            try? await userRepository.removeUserTeam(userId: memberId)
        }
        
        // Eliminar el equipo
        try await teamRepository.deleteTeam(teamId)
    }
}


