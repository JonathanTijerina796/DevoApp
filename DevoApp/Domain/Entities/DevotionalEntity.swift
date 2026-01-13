import Foundation

// MARK: - Devotional Entity (Domain Layer)
// Entidad que representa un devocional semanal de un equipo

struct DevotionalEntity: Identifiable, Equatable {
    let id: String?
    let teamId: String
    let title: String // Nombre del devocional (ej: "Alabanza")
    let startDate: Date
    let endDate: Date
    let dailyInstructions: [DailyInstruction] // Instrucciones por cada día
    let createdAt: Date
    let updatedAt: Date
    
    init(
        id: String? = nil,
        teamId: String,
        title: String,
        startDate: Date,
        endDate: Date,
        dailyInstructions: [DailyInstruction] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.teamId = teamId
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.dailyInstructions = dailyInstructions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Calcular el día actual del devocional (1-7)
    var currentDay: Int {
        let calendar = Calendar.current
        let today = Date()
        
        guard today >= startDate && today <= endDate else {
            return 1
        }
        
        let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: today).day ?? 0
        return min(max(daysSinceStart + 1, 1), 7)
    }
    
    // Obtener instrucción del día actual
    func instructionForDay(_ day: Int) -> DailyInstruction? {
        return dailyInstructions.first { $0.id == day }
    }
    
    // Verificar si el devocional está activo
    var isActive: Bool {
        let today = Date()
        return today >= startDate && today <= endDate
    }
}

// MARK: - Daily Instruction

struct DailyInstruction: Identifiable, Equatable, Codable {
    let id: Int // Día del devocional (1-7)
    let date: Date
    let instruction: String // "El día de hoy enfócate en estudiar..."
    let passage: String? // "Mateo capítulo 7"
    
    init(
        id: Int,
        date: Date,
        instruction: String,
        passage: String? = nil
    ) {
        self.id = id
        self.date = date
        self.instruction = instruction
        self.passage = passage
    }
}
