import Foundation

// MARK: - Get Active Devotional Use Case

protocol GetActiveDevotionalUseCaseProtocol {
    func execute(teamId: String) async throws -> DevotionalEntity?
}

final class GetActiveDevotionalUseCase: GetActiveDevotionalUseCaseProtocol {
    private let devotionalRepository: DevotionalRepositoryProtocol
    
    init(devotionalRepository: DevotionalRepositoryProtocol) {
        self.devotionalRepository = devotionalRepository
    }
    
    func execute(teamId: String) async throws -> DevotionalEntity? {
        return try await devotionalRepository.getActiveDevotional(teamId: teamId)
    }
}
