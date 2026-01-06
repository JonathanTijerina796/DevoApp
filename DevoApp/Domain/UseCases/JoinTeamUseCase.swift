import Foundation

// MARK: - Join Team Use Case
// Single Responsibility Principle: Una sola responsabilidad - unirse a un equipo

protocol JoinTeamUseCaseProtocol {
    func execute(code: String, userId: String) async throws -> TeamEntity
}

final class JoinTeamUseCase: JoinTeamUseCaseProtocol {
    private let teamRepository: TeamRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    
    // Dependency Injection
    init(teamRepository: TeamRepositoryProtocol, userRepository: UserRepositoryProtocol) {
        self.teamRepository = teamRepository
        self.userRepository = userRepository
    }
    
    func execute(code: String, userId: String) async throws -> TeamEntity {
        // Validar código
        let normalizedCode = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard !normalizedCode.isEmpty else {
            throw TeamError.invalidTeamCode
        }
        
        // Buscar equipo por código
        guard var team = try await teamRepository.findTeamByCode(normalizedCode) else {
            throw TeamError.teamNotFound
        }
        
        // Verificar que el usuario no sea el líder
        if team.leaderId == userId {
            throw TeamError.alreadyTeamLeader
        }
        
        // Verificar que el usuario no esté ya en el equipo
        if team.memberIds.contains(userId) {
            throw TeamError.alreadyTeamMember
        }
        
        // Agregar usuario al equipo
        try await teamRepository.addMemberToTeam(teamId: team.id ?? "", memberId: userId)
        
        // Actualizar el equipo local
        var updatedMemberIds = team.memberIds
        updatedMemberIds.append(userId)
        team = TeamEntity(
            id: team.id,
            name: team.name,
            code: team.code,
            leaderId: team.leaderId,
            leaderName: team.leaderName,
            memberIds: updatedMemberIds,
            createdAt: team.createdAt,
            updatedAt: Date()
        )
        
        // Actualizar perfil del usuario
        try await userRepository.setUserTeam(
            userId: userId,
            teamId: team.id ?? "",
            role: .member
        )
        
        return team
    }
}

