import Foundation
import FirebaseFirestore

// MARK: - Devotional Repository Implementation

final class DevotionalRepository: DevotionalRepositoryProtocol {
    private let db: Firestore
    private let devotionalsCollection = "devotionals"
    private let messagesCollection = "devotionalMessages"
    
    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }
    
    // MARK: - Devotionals
    
    func getActiveDevotional(teamId: String) async throws -> DevotionalEntity? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayTimestamp = Timestamp(date: today)
        
        print("🔍 [DevotionalRepository] Buscando devocional para teamId: \(teamId)")
        print("   Fecha de hoy: \(today)")
        print("   Timestamp de hoy: \(todayTimestamp)")
        
        // Primero buscar el más reciente del equipo (más confiable)
        let recentQuery = try await db.collection(devotionalsCollection)
            .whereField("teamId", isEqualTo: teamId)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .getDocuments()
        
        guard let recentDocument = recentQuery.documents.first else {
            print("⚠️ [DevotionalRepository] No se encontraron devocionales para el equipo")
            return nil
        }
        
        let recentData = try recentDocument.data(as: DevotionalDataModel.self)
        let devotional = recentData.toDomain()
        
        print("✅ [DevotionalRepository] Devocional encontrado:")
        print("   ID: \(devotional.id ?? "sin ID")")
        print("   Título: \(devotional.title)")
        print("   Fechas: \(devotional.startDate) - \(devotional.endDate)")
        
        // Verificar si está dentro del rango de fechas
        let startOfDay = calendar.startOfDay(for: devotional.startDate)
        let endOfDay = calendar.startOfDay(for: devotional.endDate)
        
        if startOfDay <= today && endOfDay >= today {
            print("   ✅ Devocional está activo (dentro del rango de fechas)")
            return devotional
        } else {
            print("   ⚠️ Devocional no está activo por fechas, pero se retorna el más reciente")
            print("   Start: \(startOfDay) vs Today: \(today)")
            print("   End: \(endOfDay) vs Today: \(today)")
            // Retornar el más reciente de todas formas para que el usuario lo vea
            return devotional
        }
    }
    
    func createDevotional(_ devotional: DevotionalEntity) async throws -> DevotionalEntity {
        let dataModel = DevotionalDataModel.fromDomain(devotional)
        let docRef = db.collection(devotionalsCollection).document()
        
        let data: [String: Any] = [
            "teamId": dataModel.teamId,
            "title": dataModel.title,
            "startDate": dataModel.startDate,
            "endDate": dataModel.endDate,
            "dailyInstructions": dataModel.dailyInstructions.map { instruction in
                [
                    "id": instruction.id,
                    "date": instruction.date,
                    "instruction": instruction.instruction,
                    "passage": instruction.passage as Any
                ]
            },
            "createdAt": dataModel.createdAt,
            "updatedAt": dataModel.updatedAt
        ]
        
        try await docRef.setData(data)
        
        // Actualizar con el ID generado
        return DevotionalEntity(
            id: docRef.documentID,
            teamId: devotional.teamId,
            title: devotional.title,
            startDate: devotional.startDate,
            endDate: devotional.endDate,
            dailyInstructions: devotional.dailyInstructions,
            createdAt: devotional.createdAt,
            updatedAt: devotional.updatedAt
        )
    }
    
    func getDevotionalById(_ devotionalId: String) async throws -> DevotionalEntity? {
        let document = try await db.collection(devotionalsCollection).document(devotionalId).getDocument()
        
        guard document.exists else {
            return nil
        }
        
        let data = try document.data(as: DevotionalDataModel.self)
        return data.toDomain()
    }
    
    // MARK: - Messages
    
    func getDevotionalMessages(devotionalId: String, dayNumber: Int) async throws -> [DevotionalMessageEntity] {
        let querySnapshot = try await db.collection(messagesCollection)
            .whereField("devotionalId", isEqualTo: devotionalId)
            .whereField("dayNumber", isEqualTo: dayNumber)
            .order(by: "createdAt", descending: false)
            .getDocuments()
        
        return try querySnapshot.documents.map { document in
            let data = try document.data(as: DevotionalMessageDataModel.self)
            let message = data.toDomain()
            // Actualizar con el ID del documento
            return DevotionalMessageEntity(
                id: document.documentID,
                devotionalId: message.devotionalId,
                dayNumber: message.dayNumber,
                userId: message.userId,
                userName: message.userName,
                content: message.content,
                createdAt: message.createdAt,
                updatedAt: message.updatedAt,
                isEdited: message.isEdited
            )
        }
    }
    
    func sendMessage(_ message: DevotionalMessageEntity) async throws -> DevotionalMessageEntity {
        // Verificar que no exista ya un mensaje del usuario para este día
        if (try? await getUserMessage(
            devotionalId: message.devotionalId,
            dayNumber: message.dayNumber,
            userId: message.userId
        )) != nil {
            // Si existe, actualizar en lugar de crear
            return try await updateMessage(message)
        }
        
        let dataModel = DevotionalMessageDataModel.fromDomain(message)
        let docRef = db.collection(messagesCollection).document()
        
        let data: [String: Any] = [
            "devotionalId": dataModel.devotionalId,
            "dayNumber": dataModel.dayNumber,
            "userId": dataModel.userId,
            "userName": dataModel.userName,
            "content": dataModel.content,
            "createdAt": dataModel.createdAt,
            "updatedAt": dataModel.updatedAt,
            "isEdited": dataModel.isEdited
        ]
        
        try await docRef.setData(data)
        
        return DevotionalMessageEntity(
            id: docRef.documentID,
            devotionalId: message.devotionalId,
            dayNumber: message.dayNumber,
            userId: message.userId,
            userName: message.userName,
            content: message.content,
            createdAt: message.createdAt,
            updatedAt: message.updatedAt,
            isEdited: message.isEdited
        )
    }
    
    func updateMessage(_ message: DevotionalMessageEntity) async throws -> DevotionalMessageEntity {
        guard let messageId = message.id else {
            throw NSError(domain: "DevotionalRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "Message ID is required"])
        }
        
        let dataModel = DevotionalMessageDataModel.fromDomain(message)
        
        try await db.collection(messagesCollection).document(messageId).updateData([
            "content": dataModel.content,
            "updatedAt": Timestamp(),
            "isEdited": true
        ])
        
        return DevotionalMessageEntity(
            id: messageId,
            devotionalId: message.devotionalId,
            dayNumber: message.dayNumber,
            userId: message.userId,
            userName: message.userName,
            content: message.content,
            createdAt: message.createdAt,
            updatedAt: Date(),
            isEdited: true
        )
    }
    
    func getUserMessage(devotionalId: String, dayNumber: Int, userId: String) async throws -> DevotionalMessageEntity? {
        let querySnapshot = try await db.collection(messagesCollection)
            .whereField("devotionalId", isEqualTo: devotionalId)
            .whereField("dayNumber", isEqualTo: dayNumber)
            .whereField("userId", isEqualTo: userId)
            .limit(to: 1)
            .getDocuments()
        
        guard let document = querySnapshot.documents.first else {
            return nil
        }
        
        let data = try document.data(as: DevotionalMessageDataModel.self)
        let message = data.toDomain()
        
        return DevotionalMessageEntity(
            id: document.documentID,
            devotionalId: message.devotionalId,
            dayNumber: message.dayNumber,
            userId: message.userId,
            userName: message.userName,
            content: message.content,
            createdAt: message.createdAt,
            updatedAt: message.updatedAt,
            isEdited: message.isEdited
        )
    }
    
    func deleteMessage(_ messageId: String) async throws {
        try await db.collection(messagesCollection).document(messageId).delete()
    }
}
