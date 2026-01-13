import Foundation
import FirebaseAuth

// MARK: - Get User Devotional Message Use Case

protocol GetUserDevotionalMessageUseCaseProtocol {
    func execute(devotionalId: String, dayNumber: Int) async throws -> DevotionalMessageEntity?
}

final class GetUserDevotionalMessageUseCase: GetUserDevotionalMessageUseCaseProtocol {
    private let devotionalRepository: DevotionalRepositoryProtocol
    
    init(devotionalRepository: DevotionalRepositoryProtocol) {
        self.devotionalRepository = devotionalRepository
    }
    
    func execute(devotionalId: String, dayNumber: Int) async throws -> DevotionalMessageEntity? {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw DevotionalError.userNotAuthenticated
        }
        
        return try await devotionalRepository.getUserMessage(
            devotionalId: devotionalId,
            dayNumber: dayNumber,
            userId: userId
        )
    }
}
