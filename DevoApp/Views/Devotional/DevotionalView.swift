import SwiftUI

// MARK: - Devotional View
// Vista principal del devocional con chat tipo WhatsApp

struct DevotionalView: View {
    @StateObject private var viewModel: DevotionalViewModel
    @State private var showMessageComposer = false
    let teamId: String
    
    init(teamId: String, viewModel: DevotionalViewModel) {
        self.teamId = teamId
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.devotional == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let devotional = viewModel.devotional {
                VStack(spacing: 0) {
                    // Header con nombre del equipo y rango de fechas
                    DevotionalHeaderView(devotional: devotional)
                    
                    // Instrucción del día o tema libre
                    if let instruction = viewModel.currentInstruction {
                        DailyInstructionView(instruction: instruction)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                    } else {
                        // Mostrar "Tema libre" si no hay instrucción específica
                        FreeTopicView()
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                    }
                    
                    // Indicador de progreso de días
                    DayProgressView(
                        days: viewModel.days,
                        selectedDay: $viewModel.currentDay,
                        dayStatuses: viewModel.days.map { viewModel.getDayStatus($0) },
                        onDaySelected: { day in
                            Task {
                                await viewModel.loadMessages(for: day)
                            }
                        }
                    )
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    
                    // Resumen de progreso
                    ProgressSummaryView(
                        currentDay: viewModel.currentDay,
                        totalDays: 7,
                        missedDays: viewModel.getMissedDaysCount()
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    
                    // Chat de mensajes (ocupa el espacio restante)
                    DevotionalChatView(
                        messages: viewModel.messages,
                        currentUserId: viewModel.currentUserId ?? "",
                        onEditMessage: { message in
                            viewModel.userMessage = message
                            showMessageComposer = true
                        }
                    )
                }
                .background(Color.screenBG.ignoresSafeArea())
                .overlay(alignment: .bottomTrailing) {
                    // Botón flotante para enviar/editar mensaje
                    if viewModel.userMessage == nil || viewModel.getDayStatus(viewModel.currentDay) == .current {
                        FloatingActionButton {
                            showMessageComposer = true
                        }
                        .padding()
                    }
                }
            } else {
                // No hay devocional activo
                NoDevotionalView()
            }
        }
        .background(Color.screenBG.ignoresSafeArea())
        .sheet(isPresented: $showMessageComposer) {
            MessageComposerView(
                dayNumber: viewModel.currentDay,
                instruction: viewModel.currentInstruction?.instruction ?? NSLocalizedString("free_topic_instruction", comment: ""),
                existingMessage: viewModel.userMessage,
                onSend: { content in
                    return await viewModel.sendMessage(content, day: viewModel.currentDay)
                }
            )
        }
        .task {
            await viewModel.loadDevotional(teamId: teamId)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DevotionalCreated"))) { _ in
            Task {
                await viewModel.loadDevotional(teamId: teamId)
            }
        }
    }
}

// MARK: - Devotional Header View

struct DevotionalHeaderView: View {
    let devotional: DevotionalEntity
    
    var body: some View {
        VStack(spacing: 8) {
            // Nombre del devocional
            Text(devotional.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.primaryText)
            
            // Rango de fechas
            Text(dateRangeText)
                .font(.system(size: 16))
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
    }
    
    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        let startDay = formatter.string(from: devotional.startDate)
        
        formatter.dateFormat = "d 'de' MMMM"
        let endDate = formatter.string(from: devotional.endDate)
        
        formatter.dateFormat = "MMMM"
        let month = formatter.string(from: devotional.startDate)
        
        return "\(startDay) al \(endDate)"
    }
}

// MARK: - Daily Instruction View

struct DailyInstructionView: View {
    let instruction: DailyInstruction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let passage = instruction.passage {
                Text("El pasaje de hoy es: \(passage)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.secondaryText)
            }
            
            Text(instruction.instruction)
                .font(.system(size: 16))
                .foregroundStyle(Color.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Day Progress View

struct DayProgressView: View {
    let days: [Int]
    @Binding var selectedDay: Int
    let dayStatuses: [DayStatus]
    let onDaySelected: (Int) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(days, id: \.self) { day in
                    DayButton(
                        day: day,
                        status: dayStatuses[day - 1],
                        isSelected: selectedDay == day
                    ) {
                        selectedDay = day
                        onDaySelected(day)
                    }
                }
            }
        }
    }
}

struct DayButton: View {
    let day: Int
    let status: DayStatus
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(backgroundColor)
                        .frame(width: 40, height: 40)
                    
                    if status == .completed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    } else if status == .missed {
                        Image(systemName: "exclamationmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("\(day)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(textColor)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.accentBrand : Color.clear, lineWidth: 2)
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var backgroundColor: Color {
        switch status {
        case .completed:
            return Color.green
        case .current:
            return Color.accentBrand.opacity(0.3)
        case .missed:
            return Color.orange
        case .pending:
            return Color.gray.opacity(0.2)
        }
    }
    
    private var textColor: Color {
        switch status {
        case .completed, .missed:
            return .white
        case .current:
            return .accentBrand
        case .pending:
            return .secondaryText
        }
    }
}

// MARK: - Progress Summary View

struct ProgressSummaryView: View {
    let currentDay: Int
    let totalDays: Int
    let missedDays: Int
    
    var body: some View {
        HStack(spacing: 16) {
            Text("Día \(currentDay) de \(totalDays)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.primaryText)
            
            if missedDays > 0 {
                Text("\(missedDays) día\(missedDays > 1 ? "s" : "") perdido\(missedDays > 1 ? "s" : "")")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.orange)
            }
            
            Spacer()
        }
    }
}

// MARK: - Free Topic View

struct FreeTopicView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("free_topic", comment: ""))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.accentBrand)
            
            Text(NSLocalizedString("free_topic_description", comment: ""))
                .font(.system(size: 16))
                .foregroundStyle(Color.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentBrand.opacity(0.1))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - No Devotional View

struct NoDevotionalView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.fill")
                .font(.system(size: 50))
                .foregroundStyle(Color.secondaryText)
            
            Text(NSLocalizedString("no_active_devotional", comment: ""))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.primaryText)
            
            Text(NSLocalizedString("no_devotional_description", comment: ""))
                .font(.system(size: 14))
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentBrand)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}
