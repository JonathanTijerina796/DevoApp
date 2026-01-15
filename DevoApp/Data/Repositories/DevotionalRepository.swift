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
        
        // Buscar todos los devocionales del equipo (sin orderBy para evitar necesidad de índice)
        let allQuery = try await db.collection(devotionalsCollection)
            .whereField("teamId", isEqualTo: teamId)
            .getDocuments()
        
        guard !allQuery.documents.isEmpty else {
            print("⚠️ [DevotionalRepository] No se encontraron devocionales para el equipo")
            return nil
        }
        
        // Ordenar en memoria por createdAt (más reciente primero)
        let sortedDocuments = allQuery.documents.sorted { doc1, doc2 in
            let date1 = (doc1.data()["createdAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
            let date2 = (doc2.data()["createdAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
            return date1 > date2
        }
        
        guard let recentDocument = sortedDocuments.first else {
            print("⚠️ [DevotionalRepository] No se pudo ordenar los documentos")
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
        // Obtener mensajes sin orderBy para evitar necesidad de índice compuesto
        let querySnapshot = try await db.collection(messagesCollection)
            .whereField("devotionalId", isEqualTo: devotionalId)
            .whereField("dayNumber", isEqualTo: dayNumber)
            .getDocuments()
        
        // Mapear y ordenar en memoria
        let messages = try querySnapshot.documents.map { document -> DevotionalMessageEntity in
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
        
        // Ordenar por createdAt en memoria
        return messages.sorted { $0.createdAt < $1.createdAt }
    }
    
    func sendMessage(_ message: DevotionalMessageEntity) async throws -> DevotionalMessageEntity {
        print("💾 [DevotionalRepository] Enviando mensaje...")
        print("   devotionalId: \(message.devotionalId)")
        print("   dayNumber: \(message.dayNumber)")
        print("   userId: \(message.userId)")
        print("   content: \(message.content.prefix(50))...")
        
        // Verificar que no exista ya un mensaje del usuario para este día
        if let existingMessage = try? await getUserMessage(
            devotionalId: message.devotionalId,
            dayNumber: message.dayNumber,
            userId: message.userId
        ) {
            print("⚠️ [DevotionalRepository] Mensaje existente encontrado, actualizando...")
            print("   ID del mensaje existente: \(existingMessage.id ?? "sin ID")")
            
            // Si existe, actualizar en lugar de crear
            // Usar el ID del mensaje existente
            let messageToUpdate = DevotionalMessageEntity(
                id: existingMessage.id,
                devotionalId: message.devotionalId,
                dayNumber: message.dayNumber,
                userId: message.userId,
                userName: message.userName,
                content: message.content,
                createdAt: existingMessage.createdAt,
                updatedAt: Date(),
                isEdited: true
            )
            return try await updateMessage(messageToUpdate)
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
        
        print("💾 [DevotionalRepository] Guardando mensaje en Firestore...")
        print("   Document ID: \(docRef.documentID)")
        print("   Data: \(data)")
        
        try await docRef.setData(data)
        
        print("✅ [DevotionalRepository] Mensaje guardado exitosamente con ID: \(docRef.documentID)")
        
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
            print("❌ [DevotionalRepository] Error: Message ID es nil")
            throw NSError(domain: "DevotionalRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "Message ID is required"])
        }
        
        print("🔄 [DevotionalRepository] Actualizando mensaje...")
        print("   messageId: \(messageId)")
        print("   content: \(message.content.prefix(50))...")
        
        let dataModel = DevotionalMessageDataModel.fromDomain(message)
        
        let updateData: [String: Any] = [
            "content": dataModel.content,
            "updatedAt": Timestamp(),
            "isEdited": true
        ]
        
        print("💾 [DevotionalRepository] Actualizando documento en Firestore...")
        print("   Update data: \(updateData)")
        
        try await db.collection(messagesCollection).document(messageId).updateData(updateData)
        
        print("✅ [DevotionalRepository] Mensaje actualizado exitosamente")
        
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
    
    // MARK: - Real-time Listeners
    
    func listenToMessages(
        devotionalId: String,
        dayNumber: Int,
        onUpdate: @escaping ([DevotionalMessageEntity]) -> Void
    ) -> ListenerRegistration {
        print("👂 [DevotionalRepository] Configurando listener para devotionalId: \(devotionalId), dayNumber: \(dayNumber)")
        
        // Usar consulta sin orderBy para evitar necesidad de índice compuesto
        // Ordenaremos en memoria después de recibir los documentos
        return db.collection(messagesCollection)
            .whereField("devotionalId", isEqualTo: devotionalId)
            .whereField("dayNumber", isEqualTo: dayNumber)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    print("❌ [DevotionalRepository] Error en listener de mensajes: \(error.localizedDescription)")
                    return
                }
                
                guard let querySnapshot = querySnapshot else {
                    print("⚠️ [DevotionalRepository] QuerySnapshot es nil")
                    onUpdate([])
                    return
                }
                
                // Información de metadata para debugging
                let isFromCache = querySnapshot.metadata.isFromCache
                let hasPendingWrites = querySnapshot.metadata.hasPendingWrites
                
                print("📄 [DevotionalRepository] Listener recibió \(querySnapshot.documents.count) documentos")
                print("   isFromCache: \(isFromCache)")
                print("   hasPendingWrites: \(hasPendingWrites)")
                
                // Procesar todos los cambios, incluso los locales
                // El listener de Firestore maneja la sincronización automáticamente
                
                let documents = querySnapshot.documents
                
                let unsortedMessages = documents.compactMap { document -> DevotionalMessageEntity? in
                    do {
                        // Usar document.documentID directamente para evitar problemas con @DocumentID
                        let documentId = document.documentID
                        let documentData = document.data()
                        
                        // Parsear manualmente para tener control total
                        guard let devotionalId = documentData["devotionalId"] as? String,
                              let dayNumber = documentData["dayNumber"] as? Int,
                              let userId = documentData["userId"] as? String,
                              let userName = documentData["userName"] as? String,
                              let content = documentData["content"] as? String,
                              let createdAt = documentData["createdAt"] as? Timestamp,
                              let updatedAt = documentData["updatedAt"] as? Timestamp else {
                            print("⚠️ [DevotionalRepository] Campos faltantes en documento \(documentId)")
                            return nil
                        }
                        
                        let isEdited = documentData["isEdited"] as? Bool ?? false
                        
                        // Asegurar que el ID nunca sea nil
                        guard !documentId.isEmpty else {
                            print("⚠️ [DevotionalRepository] Document ID vacío, saltando mensaje")
                            return nil
                        }
                        
                        let entity = DevotionalMessageEntity(
                            id: documentId,
                            devotionalId: devotionalId,
                            dayNumber: dayNumber,
                            userId: userId,
                            userName: userName,
                            content: content,
                            createdAt: createdAt.dateValue(),
                            updatedAt: updatedAt.dateValue(),
                            isEdited: isEdited
                        )
                        print("   📝 Mensaje [\(documentId)]: \(entity.userName) - \(entity.content.prefix(30))...")
                        return entity
                    } catch {
                        print("❌ [DevotionalRepository] Error al parsear mensaje \(document.documentID): \(error.localizedDescription)")
                        print("   Document data: \(document.data())")
                        return nil
                    }
                }
                
                // Ordenar por createdAt en memoria
                let messages = unsortedMessages.sorted { $0.createdAt < $1.createdAt }
                
                print("📨 [DevotionalRepository] Listener actualizado: \(messages.count) mensajes procesados y ordenados")
                onUpdate(messages)
            }
    }
    
    // MARK: - Delete Operations
    
    func deleteDevotionalsForTeam(teamId: String) async throws {
        print("🗑️ [DevotionalRepository] Eliminando devocionales del equipo: \(teamId)")
        
        // Obtener todos los devocionales del equipo
        let devotionalsQuery = try await db.collection(devotionalsCollection)
            .whereField("teamId", isEqualTo: teamId)
            .getDocuments()
        
        print("   📚 Encontrados \(devotionalsQuery.documents.count) devocionales")
        
        // Obtener todos los mensajes de esos devocionales
        var allMessageIds: [String] = []
        var devotionalIds: [String] = []
        
        for devotionalDoc in devotionalsQuery.documents {
            let devotionalId = devotionalDoc.documentID
            devotionalIds.append(devotionalId)
            
            // Obtener todos los mensajes de este devocional
            let messagesQuery = try await db.collection(messagesCollection)
                .whereField("devotionalId", isEqualTo: devotionalId)
                .getDocuments()
            
            let messageIds = messagesQuery.documents.map { $0.documentID }
            allMessageIds.append(contentsOf: messageIds)
        }
        
        print("   💬 Encontrados \(allMessageIds.count) mensajes")
        
        // Eliminar en batch
        let batch = db.batch()
        
        // Eliminar mensajes
        for messageId in allMessageIds {
            let messageRef = db.collection(messagesCollection).document(messageId)
            batch.deleteDocument(messageRef)
        }
        
        // Eliminar devocionales
        for devotionalId in devotionalIds {
            let devotionalRef = db.collection(devotionalsCollection).document(devotionalId)
            batch.deleteDocument(devotionalRef)
        }
        
        // Ejecutar batch
        try await batch.commit()
        
        print("✅ [DevotionalRepository] Eliminados \(devotionalIds.count) devocionales y \(allMessageIds.count) mensajes")
    }
    
    func deleteExpiredDevotionals() async throws -> Int {
        print("🗑️ [DevotionalRepository] Buscando devocionales vencidos...")
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayTimestamp = Timestamp(date: today)
        
        // Obtener todos los devocionales
        let allDevotionals = try await db.collection(devotionalsCollection)
            .getDocuments()
        
        var expiredDevotionalIds: [String] = []
        var allMessageIds: [String] = []
        
        // Filtrar devocionales vencidos (endDate < today)
        for doc in allDevotionals.documents {
            if let endDate = doc.data()["endDate"] as? Timestamp {
                let endDateValue = endDate.dateValue()
                let endDateStart = calendar.startOfDay(for: endDateValue)
                
                // Si la fecha de fin ya pasó (más de 1 día después)
                if endDateStart < today {
                    let devotionalId = doc.documentID
                    expiredDevotionalIds.append(devotionalId)
                    
                    // Obtener todos los mensajes de este devocional
                    let messagesQuery = try await db.collection(messagesCollection)
                        .whereField("devotionalId", isEqualTo: devotionalId)
                        .getDocuments()
                    
                    let messageIds = messagesQuery.documents.map { $0.documentID }
                    allMessageIds.append(contentsOf: messageIds)
                }
            }
        }
        
        print("   📚 Encontrados \(expiredDevotionalIds.count) devocionales vencidos")
        print("   💬 Encontrados \(allMessageIds.count) mensajes asociados")
        
        if expiredDevotionalIds.isEmpty {
            print("✅ [DevotionalRepository] No hay devocionales vencidos")
            return 0
        }
        
        // Eliminar en batch
        let batch = db.batch()
        
        // Eliminar mensajes
        for messageId in allMessageIds {
            let messageRef = db.collection(messagesCollection).document(messageId)
            batch.deleteDocument(messageRef)
        }
        
        // Eliminar devocionales
        for devotionalId in expiredDevotionalIds {
            let devotionalRef = db.collection(devotionalsCollection).document(devotionalId)
            batch.deleteDocument(devotionalRef)
        }
        
        // Ejecutar batch
        try await batch.commit()
        
        print("✅ [DevotionalRepository] Eliminados \(expiredDevotionalIds.count) devocionales vencidos y \(allMessageIds.count) mensajes")
        
        return expiredDevotionalIds.count
    }
}
