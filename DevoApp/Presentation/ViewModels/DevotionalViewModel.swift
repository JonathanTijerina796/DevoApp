import Foundation
import FirebaseAuth

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
        guard let devotionalId = devotional?.id else { return }
        
        currentDay = day
        isLoading = true
        
        defer { isLoading = false }
        
        do {
            messages = try await getMessagesUseCase.execute(
                devotionalId: devotionalId,
                dayNumber: day
            )
            
            // Cargar mensaje del usuario actual
            userMessage = try await getUserMessageUseCase.execute(
                devotionalId: devotionalId,
                dayNumber: day
            )
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
    
    // MARK: - Send Message
    
    func sendMessage(_ content: String, day: Int) async -> Bool {
        guard let devotionalId = devotional?.id else {
            errorMessage = NSLocalizedString("devotional_not_found", comment: "")
            return false
        }
        
        isLoading = true
        errorMessage = ""
        
        defer { isLoading = false }
        
        do {
            // Si ya existe un mensaje del usuario, actualizarlo
            if let existingMessage = userMessage {
                var updatedMessage = existingMessage
                updatedMessage = DevotionalMessageEntity(
                    id: existingMessage.id,
                    devotionalId: existingMessage.devotionalId,
                    dayNumber: existingMessage.dayNumber,
                    userId: existingMessage.userId,
                    userName: existingMessage.userName,
                    content: content,
                    createdAt: existingMessage.createdAt,
                    updatedAt: Date(),
                    isEdited: true
                )
                
                let updated = try await devotionalRepository.updateMessage(updatedMessage)
                userMessage = updated
                
                // Actualizar en la lista de mensajes
                if let index = messages.firstIndex(where: { $0.id == existingMessage.id }) {
                    messages[index] = updated
                }
            } else {
                // Crear nuevo mensaje
                let newMessage = try await sendMessageUseCase.execute(
                    devotionalId: devotionalId,
                    dayNumber: day,
                    content: content
                )
                
                userMessage = newMessage
                messages.append(newMessage)
            }
            
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
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
