import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Devotional ViewModel

@MainActor
final class DevotionalViewModel: ObservableObject {
    @Published var devotional: DevotionalEntity?
    @Published var messages: [DevotionalMessageEntity] = []
    @Published var currentDay: Int = 1
    @Published var userMessage: DevotionalMessageEntity?
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // Dependencias no aisladas al main actor para permitir inicialización desde cualquier contexto
    nonisolated(unsafe) private let getActiveDevotionalUseCase: GetActiveDevotionalUseCaseProtocol
    nonisolated(unsafe) private let sendMessageUseCase: SendDevotionalMessageUseCaseProtocol
    nonisolated(unsafe) private let getMessagesUseCase: GetDevotionalMessagesUseCaseProtocol
    nonisolated(unsafe) private let getUserMessageUseCase: GetUserDevotionalMessageUseCaseProtocol
    nonisolated(unsafe) private let devotionalRepository: DevotionalRepositoryProtocol
    
    // Listener para mensajes en tiempo real
    private var messagesListener: ListenerRegistration?
    
    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    var currentInstruction: DailyInstruction? {
        guard let devotional = devotional else { return nil }
        return devotional.instructionForDay(currentDay)
    }
    
    var days: [Int] {
        return Array(1...7)
    }
    
    // Inicializador no aislado al main actor para permitir creación desde cualquier contexto
    nonisolated init(
        getActiveDevotionalUseCase: GetActiveDevotionalUseCaseProtocol,
        sendMessageUseCase: SendDevotionalMessageUseCaseProtocol,
        getMessagesUseCase: GetDevotionalMessagesUseCaseProtocol,
        getUserMessageUseCase: GetUserDevotionalMessageUseCaseProtocol,
        devotionalRepository: DevotionalRepositoryProtocol
    ) {
        self.getActiveDevotionalUseCase = getActiveDevotionalUseCase
        self.sendMessageUseCase = sendMessageUseCase
        self.getMessagesUseCase = getMessagesUseCase
        self.getUserMessageUseCase = getUserMessageUseCase
        self.devotionalRepository = devotionalRepository
    }
    
    deinit {
        // Limpiar listener cuando el ViewModel se destruya
        messagesListener?.remove()
    }
    
    // MARK: - Reset
    
    func reset() async {
        stopListening()
        devotional = nil
        messages = []
        currentDay = 1
        userMessage = nil
        isLoading = false
        errorMessage = ""
    }
    
    // MARK: - Listener Management
    
    private func stopListening() {
        messagesListener?.remove()
        messagesListener = nil
    }
    
    // MARK: - Load Devotional
    
    func loadDevotional(teamId: String) async {
        isLoading = true
        errorMessage = ""
        
        defer { isLoading = false }
        
        do {
            print("🔍 Buscando devocional activo para teamId: \(teamId)")
            devotional = try await getActiveDevotionalUseCase.execute(teamId: teamId)
            
            if let devotional = devotional {
                print("✅ Devocional encontrado: \(devotional.title)")
                print("   ID: \(devotional.id ?? "sin ID")")
                print("   Fechas: \(devotional.startDate) - \(devotional.endDate)")
                currentDay = devotional.currentDay
                await loadMessages(for: currentDay)
            } else {
                print("⚠️ No se encontró devocional activo para el equipo")
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            print("❌ Error al cargar devocional: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Load Messages
    
    func loadMessages(for day: Int) async {
        guard let devotionalId = devotional?.id else {
            print("⚠️ [DevotionalViewModel] No se puede cargar mensajes: devotionalId es nil")
            return
        }
        
        print("📥 [DevotionalViewModel] Cargando mensajes para día \(day)...")
        
        // Detener listener anterior si existe
        stopListening()
        
        currentDay = day
        isLoading = true
        
        defer { isLoading = false }
        
        do {
            // Cargar mensajes iniciales
            print("📥 [DevotionalViewModel] Obteniendo mensajes del use case...")
            let loadedMessages = try await getMessagesUseCase.execute(
                devotionalId: devotionalId,
                dayNumber: day
            )
            print("✅ [DevotionalViewModel] Mensajes cargados: \(loadedMessages.count)")
            messages = loadedMessages
            
            // Cargar mensaje del usuario actual
            print("📥 [DevotionalViewModel] Obteniendo mensaje del usuario...")
            userMessage = try await getUserMessageUseCase.execute(
                devotionalId: devotionalId,
                dayNumber: day
            )
            if let userMsg = userMessage {
                print("✅ [DevotionalViewModel] Mensaje del usuario encontrado: \(userMsg.id ?? "sin ID")")
            } else {
                print("ℹ️ [DevotionalViewModel] El usuario no tiene mensaje para este día")
            }
            
            // Iniciar listener en tiempo real
            print("👂 [DevotionalViewModel] Iniciando listener...")
            startListening(devotionalId: devotionalId, dayNumber: day)
            
            print("✅ [DevotionalViewModel] Carga de mensajes completada. Total: \(messages.count)")
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            print("❌ [DevotionalViewModel] Error al cargar mensajes: \(error.localizedDescription)")
        }
    }
    
    private func startListening(devotionalId: String, dayNumber: Int) {
        // Detener listener anterior si existe
        stopListening()
        
        print("👂 [DevotionalViewModel] Iniciando listener para devotionalId: \(devotionalId), dayNumber: \(dayNumber)")
        print("   currentUserId: \(currentUserId ?? "nil")")
        
        messagesListener = devotionalRepository.listenToMessages(
            devotionalId: devotionalId,
            dayNumber: dayNumber
        ) { [weak self] updatedMessages in
            // Asegurar que se ejecute en el hilo principal
            Task { @MainActor [weak self] in
                guard let self = self else { 
                    print("⚠️ [DevotionalViewModel] Self es nil en callback del listener")
                    return 
                }
                print("📨 [DevotionalViewModel] Listener callback recibido: \(updatedMessages.count) mensajes")
                
                // Log de IDs de mensajes recibidos
                let messageIds = updatedMessages.compactMap { $0.id }
                print("   IDs de mensajes recibidos: \(messageIds)")
                print("   Contenidos: \(updatedMessages.map { "\($0.userName): \($0.content.prefix(20))" })")
                
                // Verificar que estamos en el hilo principal
                assert(Thread.isMainThread, "Listener debe ejecutarse en el hilo principal")
                
                // Actualizar mensajes en el hilo principal
                self.messages = updatedMessages
                print("   ✅ Mensajes actualizados en ViewModel. Total: \(self.messages.count)")
                
                // Log de IDs después de actualizar
                let currentIds = self.messages.compactMap { $0.id }
                print("   IDs actuales en ViewModel: \(currentIds)")
                
                // Forzar actualización de la UI
                self.objectWillChange.send()
                
                // Actualizar userMessage si existe
                if let userId = self.currentUserId {
                    if let userMsg = updatedMessages.first(where: { $0.userId == userId && $0.dayNumber == dayNumber }) {
                        print("   ✅ Mensaje del usuario encontrado: \(userMsg.id ?? "sin ID")")
                        self.userMessage = userMsg
                    } else {
                        print("   ⚠️ No se encontró mensaje del usuario en la lista actualizada")
                        // Si no hay mensaje del usuario en la lista actualizada, verificar si existía antes
                        if let existingUserMsg = self.userMessage,
                           !updatedMessages.contains(where: { $0.id == existingUserMsg.id }) {
                            print("   🗑️ Mensaje del usuario ya no existe, limpiando userMessage")
                            self.userMessage = nil
                        }
                    }
                } else {
                    print("   ⚠️ currentUserId es nil")
                }
            }
        }
        
        print("✅ [DevotionalViewModel] Listener iniciado correctamente")
    }
    
    // MARK: - Send Message
    
    func sendMessage(_ content: String, day: Int) async -> Bool {
        // Validar contenido
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            errorMessage = NSLocalizedString("message_content_required", comment: "")
            print("❌ [DevotionalViewModel] Contenido vacío")
            return false
        }
        
        guard let devotionalId = devotional?.id else {
            errorMessage = NSLocalizedString("devotional_not_found", comment: "")
            print("❌ [DevotionalViewModel] No se encontró devocional")
            return false
        }
        
        print("📤 [DevotionalViewModel] Enviando mensaje...")
        print("   devotionalId: \(devotionalId)")
        print("   dayNumber: \(day)")
        print("   content length: \(trimmedContent.count) caracteres")
        print("   userMessage existente: \(userMessage != nil ? "Sí" : "No")")
        
        isLoading = true
        errorMessage = ""
        
        defer { 
            isLoading = false
            print("🔄 [DevotionalViewModel] isLoading = false")
        }
        
        do {
            // Si ya existe un mensaje del usuario, actualizarlo
            if let existingMessage = userMessage {
                print("🔄 [DevotionalViewModel] Actualizando mensaje existente...")
                print("   ID del mensaje: \(existingMessage.id ?? "sin ID")")
                
                guard let messageId = existingMessage.id else {
                    errorMessage = "Error: ID del mensaje no encontrado"
                    print("❌ [DevotionalViewModel] ID del mensaje es nil")
                    return false
                }
                
                let updatedMessage = DevotionalMessageEntity(
                    id: messageId,
                    devotionalId: existingMessage.devotionalId,
                    dayNumber: existingMessage.dayNumber,
                    userId: existingMessage.userId,
                    userName: existingMessage.userName,
                    content: trimmedContent,
                    createdAt: existingMessage.createdAt,
                    updatedAt: Date(),
                    isEdited: true
                )
                
                // El listener actualizará automáticamente los mensajes
                let updated = try await devotionalRepository.updateMessage(updatedMessage)
                print("✅ [DevotionalViewModel] Mensaje actualizado: \(updated.id ?? "sin ID")")
            } else {
                print("✨ [DevotionalViewModel] Creando nuevo mensaje...")
                // Crear nuevo mensaje usando el use case (incluye validación)
                // El listener actualizará automáticamente los mensajes
                let newMessage = try await sendMessageUseCase.execute(
                    devotionalId: devotionalId,
                    dayNumber: day,
                    content: trimmedContent
                )
                print("✅ [DevotionalViewModel] Mensaje creado: \(newMessage.id ?? "sin ID")")
                
                // Actualizar userMessage inmediatamente
                userMessage = newMessage
                print("   ✅ userMessage actualizado con nuevo mensaje")
            }
            
            // Esperar un momento para que el listener procese el cambio
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 segundos
            
            // Verificar que el mensaje esté en la lista
            print("🔍 [DevotionalViewModel] Verificando mensajes después de enviar...")
            print("   Total de mensajes: \(messages.count)")
            if let sentMessageId = userMessage?.id {
                let messageExists = messages.contains { $0.id == sentMessageId }
                print("   Mensaje en lista: \(messageExists ? "Sí" : "No")")
                
                // Si no está en la lista, forzar recarga
                if !messageExists {
                    print("⚠️ [DevotionalViewModel] Mensaje no está en la lista, recargando...")
                    await loadMessages(for: day)
                }
            }
            
            print("✅ [DevotionalViewModel] Mensaje enviado exitosamente")
            return true
        } catch {
            let errorDesc = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = errorDesc
            print("❌ [DevotionalViewModel] Error al enviar mensaje:")
            print("   Error: \(errorDesc)")
            print("   Tipo: \(type(of: error))")
            if let nsError = error as NSError? {
                print("   Domain: \(nsError.domain)")
                print("   Code: \(nsError.code)")
                print("   UserInfo: \(nsError.userInfo)")
            }
            return false
        }
    }
    
    // MARK: - Day Progress
    
    func getDayStatus(_ day: Int) -> DayStatus {
        guard let userId = currentUserId else { return .pending }
        
        let hasMessage = messages.contains { $0.userId == userId && $0.dayNumber == day }
        let isToday = day == (devotional?.currentDay ?? 1)
        let isPast = day < (devotional?.currentDay ?? 1)
        
        if hasMessage {
            return .completed
        } else if isPast {
            return .missed
        } else if isToday {
            return .current
        } else {
            return .pending
        }
    }
    
    func getMissedDaysCount() -> Int {
        guard let userId = currentUserId else { return 0 }
        
        let pastDays = days.filter { $0 < (devotional?.currentDay ?? 1) }
        let missedDays = pastDays.filter { day in
            !messages.contains { $0.userId == userId && $0.dayNumber == day }
        }
        
        return missedDays.count
    }
}

// MARK: - Day Status

enum DayStatus {
    case completed
    case current
    case missed
    case pending
}
