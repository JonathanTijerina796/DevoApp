import Foundation

// MARK: - Get User Teams Use Case
// Obtiene todos los equipos a los que pertenece el usuario con sus detalles completos

protocol GetUserTeamsUseCaseProtocol {
    func execute(userId: String) async throws -> [TeamEntity]
}

final class GetUserTeamsUseCase: GetUserTeamsUseCaseProtocol {
    private let userRepository: UserRepositoryProtocol
    private let teamRepository: TeamRepositoryProtocol
    
    init(userRepository: UserRepositoryProtocol, teamRepository: TeamRepositoryProtocol) {
        self.userRepository = userRepository
        self.teamRepository = teamRepository
    }
    
    func execute(userId: String) async throws -> [TeamEntity] {
        // Obtener los equipos del usuario
        let userTeams = await userRepository.getUserTeams(userId)
        
        // Obtener los detalles completos de cada equipo
        var teams: [TeamEntity] = []
        for userTeam in userTeams {
            if let team = try await teamRepository.getTeamById(userTeam.teamId) {
                teams.append(team)
            }
        }
        
        return teams
    }
}
