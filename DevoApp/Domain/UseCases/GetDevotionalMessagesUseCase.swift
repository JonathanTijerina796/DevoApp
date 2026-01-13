import Foundation

// MARK: - Get Devotional Messages Use Case

protocol GetDevotionalMessagesUseCaseProtocol {
    func execute(devotionalId: String, dayNumber: Int) async throws -> [DevotionalMessageEntity]
}

final class GetDevotionalMessagesUseCase: GetDevotionalMessagesUseCaseProtocol {
    private let devotionalRepository: DevotionalRepositoryProtocol
    
    init(devotionalRepository: DevotionalRepositoryProtocol) {
        self.devotionalRepository = devotionalRepository
    }
    
    func execute(devotionalId: String, dayNumber: Int) async throws -> [DevotionalMessageEntity] {
        return try await devotionalRepository.getDevotionalMessages(
            devotionalId: devotionalId,
            dayNumber: dayNumber
        )
    }
}
