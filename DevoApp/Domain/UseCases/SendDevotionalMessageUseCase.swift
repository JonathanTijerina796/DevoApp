import Foundation
import FirebaseAuth

// MARK: - Send Devotional Message Use Case

protocol SendDevotionalMessageUseCaseProtocol {
    func execute(devotionalId: String, dayNumber: Int, content: String) async throws -> DevotionalMessageEntity
}

final class SendDevotionalMessageUseCase: SendDevotionalMessageUseCaseProtocol {
    private let devotionalRepository: DevotionalRepositoryProtocol
    
    init(devotionalRepository: DevotionalRepositoryProtocol) {
        self.devotionalRepository = devotionalRepository
    }
    
    func execute(devotionalId: String, dayNumber: Int, content: String) async throws -> DevotionalMessageEntity {
        // Validar usuario autenticado
        guard let user = Auth.auth().currentUser else {
            throw DevotionalError.userNotAuthenticated
        }
        
        // Validar contenido
        let trimmedContent = content.trimmingCharacters(in: .whitespaces)
        guard !trimmedContent.isEmpty else {
            throw DevotionalError.messageContentRequired
        }
        
        // Obtener nombre del usuario
        let userName = user.displayName ?? user.email ?? "Usuario"
        
        // Crear mensaje
        let message = DevotionalMessageEntity(
            devotionalId: devotionalId,
            dayNumber: dayNumber,
            userId: user.uid,
            userName: userName,
            content: trimmedContent
        )
        
        // Enviar mensaje
        return try await devotionalRepository.sendMessage(message)
    }
}

// MARK: - Devotional Errors

enum DevotionalError: LocalizedError {
    case userNotAuthenticated
    case messageContentRequired
    case devotionalNotFound
    case messageNotFound
    case unauthorizedEdit
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return NSLocalizedString("user_not_authenticated", comment: "")
        case .messageContentRequired:
            return NSLocalizedString("message_content_required", comment: "")
        case .devotionalNotFound:
            return NSLocalizedString("devotional_not_found", comment: "")
        case .messageNotFound:
            return NSLocalizedString("message_not_found", comment: "")
        case .unauthorizedEdit:
            return NSLocalizedString("unauthorized_edit", comment: "")
        }
    }
}
