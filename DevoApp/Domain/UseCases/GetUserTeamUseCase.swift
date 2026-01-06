import Foundation

// MARK: - Get User Team Use Case

protocol GetUserTeamUseCaseProtocol {
    func execute(userId: String) async throws -> TeamEntity?
}

final class GetUserTeamUseCase: GetUserTeamUseCaseProtocol {
    private let userRepository: UserRepositoryProtocol
    private let teamRepository: TeamRepositoryProtocol
    
    init(userRepository: UserRepositoryProtocol, teamRepository: TeamRepositoryProtocol) {
        self.userRepository = userRepository
        self.teamRepository = teamRepository
    }
    
    func execute(userId: String) async throws -> TeamEntity? {
        guard let teamId = try await userRepository.getUserTeamId(userId) else {
            return nil
        }
        
        return try await teamRepository.getTeamById(teamId)
    }
}

