import Foundation
import FirebaseFirestore

// MARK: - Devotional Repository Protocol
// Protocolo para acceso a datos de devocionales

protocol DevotionalRepositoryProtocol {
    // Devocionales
    func getActiveDevotional(teamId: String) async throws -> DevotionalEntity?
    func createDevotional(_ devotional: DevotionalEntity) async throws -> DevotionalEntity
    func getDevotionalById(_ devotionalId: String) async throws -> DevotionalEntity?
    
    // Mensajes
    func getDevotionalMessages(devotionalId: String, dayNumber: Int) async throws -> [DevotionalMessageEntity]
    func sendMessage(_ message: DevotionalMessageEntity) async throws -> DevotionalMessageEntity
    func updateMessage(_ message: DevotionalMessageEntity) async throws -> DevotionalMessageEntity
    func getUserMessage(devotionalId: String, dayNumber: Int, userId: String) async throws -> DevotionalMessageEntity?
    func deleteMessage(_ messageId: String) async throws
    
    // Listener en tiempo real para mensajes
    func listenToMessages(
        devotionalId: String,
        dayNumber: Int,
        onUpdate: @escaping ([DevotionalMessageEntity]) -> Void
    ) -> ListenerRegistration
}
