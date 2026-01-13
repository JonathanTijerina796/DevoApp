import Foundation
import FirebaseAuth

// MARK: - Update Devotional Message Use Case

protocol UpdateDevotionalMessageUseCaseProtocol {
    func execute(messageId: String, content: String) async throws -> DevotionalMessageEntity
}

final class UpdateDevotionalMessageUseCase: UpdateDevotionalMessageUseCaseProtocol {
    private let devotionalRepository: DevotionalRepositoryProtocol
    
    init(devotionalRepository: DevotionalRepositoryProtocol) {
        self.devotionalRepository = devotionalRepository
    }
    
    func execute(messageId: String, content: String) async throws -> DevotionalMessageEntity {
        // Validar usuario autenticado
        guard Auth.auth().currentUser != nil else {
            throw DevotionalError.userNotAuthenticated
        }
        
        // Validar contenido
        let trimmedContent = content.trimmingCharacters(in: .whitespaces)
        guard !trimmedContent.isEmpty else {
            throw DevotionalError.messageContentRequired
        }
        
        // Este use case no se usa actualmente
        // La actualización se maneja en DevotionalViewModel usando updateMessage del repository
        throw NSError(domain: "UpdateDevotionalMessageUseCase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Use sendMessage with existing message ID instead"])
    }
}
