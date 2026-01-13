import SwiftUI

// MARK: - Create Devotional View
// Vista para que los líderes creen devocionales con temas específicos

struct CreateDevotionalView: View {
    let teamId: String
    let teamName: String
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var viewModel = CreateDevotionalViewModel(
        createDevotionalUseCase: DependencyContainer.shared.createDevotionalUseCase
    )
    
    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var instructions: [String] = Array(repeating: "", count: 7)
    @State private var passages: [String] = Array(repeating: "", count: 7)
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("devotional_info", comment: ""))) {
                    TextField(NSLocalizedString("devotional_title", comment: ""), text: $title)
                    
                    DatePicker(
                        NSLocalizedString("start_date", comment: ""),
                        selection: $startDate,
                        displayedComponents: .date
                    )
                    
                    DatePicker(
                        NSLocalizedString("end_date", comment: ""),
                        selection: $endDate,
                        displayedComponents: .date
                    )
                }
                
                Section(header: Text(NSLocalizedString("daily_instructions", comment: ""))) {
                    ForEach(0..<7, id: \.self) { day in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(NSLocalizedString("day", comment: "")) \(day + 1)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.accentBrand)
                            
                            TextField(
                                NSLocalizedString("instruction_placeholder", comment: ""),
                                text: $instructions[day],
                                axis: .vertical
                            )
                            .lineLimit(3...6)
                            
                            TextField(
                                NSLocalizedString("passage_optional", comment: ""),
                                text: $passages[day]
                            )
                            .font(.system(size: 14))
                            .foregroundStyle(Color.secondaryText)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("create_devotional", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("cancel", comment: "")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("create", comment: "")) {
                        Task {
                            await createDevotional()
                        }
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        endDate > startDate &&
        instructions.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
    
    private func createDevotional() async {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        
        var dailyInstructions: [DailyInstruction] = []
        for day in 0..<7 {
            if let dayDate = calendar.date(byAdding: .day, value: day, to: start) {
                dailyInstructions.append(DailyInstruction(
                    id: day + 1,
                    date: dayDate,
                    instruction: instructions[day].trimmingCharacters(in: .whitespaces),
                    passage: passages[day].trimmingCharacters(in: .whitespaces).isEmpty ? nil : passages[day].trimmingCharacters(in: .whitespaces)
                ))
            }
        }
        
        let success = await viewModel.createDevotional(
            teamId: teamId,
            title: title.trimmingCharacters(in: .whitespaces),
            startDate: start,
            endDate: end,
            dailyInstructions: dailyInstructions
        )
        
        if success {
            print("✅ [CreateDevotionalView] Devocional creado, esperando a que Firestore lo guarde...")
            print("   TeamId usado: \(teamId)")
            // Delay más largo para asegurar que Firestore haya guardado el documento
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 segundos
            print("📢 [CreateDevotionalView] Enviando notificación DevotionalCreated con teamId: \(teamId)")
            // Notificar que se creó un devocional, incluyendo el teamId en el userInfo
            NotificationCenter.default.post(
                name: NSNotification.Name("DevotionalCreated"),
                object: nil,
                userInfo: ["teamId": teamId]
            )
            dismiss()
        } else {
            print("❌ [CreateDevotionalView] Error al crear devocional")
        }
    }
}

// MARK: - Create Devotional ViewModel

@MainActor
class CreateDevotionalViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let createDevotionalUseCase: CreateDevotionalUseCaseProtocol
    
    init(createDevotionalUseCase: CreateDevotionalUseCaseProtocol) {
        self.createDevotionalUseCase = createDevotionalUseCase
    }
    
    func createDevotional(
        teamId: String,
        title: String,
        startDate: Date,
        endDate: Date,
        dailyInstructions: [DailyInstruction]
    ) async -> Bool {
        isLoading = true
        errorMessage = ""
        
        defer { isLoading = false }
        
        do {
            let created = try await createDevotionalUseCase.execute(
                teamId: teamId,
                title: title,
                startDate: startDate,
                endDate: endDate,
                dailyInstructions: dailyInstructions
            )
            print("✅ Devocional creado exitosamente: \(created.id ?? "sin ID")")
            print("   Título: \(created.title)")
            print("   Fechas: \(created.startDate) - \(created.endDate)")
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            print("❌ Error al crear devocional: \(error.localizedDescription)")
            return false
        }
    }
}
