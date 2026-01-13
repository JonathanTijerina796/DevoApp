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
                ScrollView {
                    VStack(spacing: 0) {
                        // Header con nombre del devocional y rango de fechas
                        DevotionalHeaderView(devotional: devotional)
                        
                        // Instrucción del día o tema libre
                        if let instruction = viewModel.currentInstruction {
                            DailyInstructionView(instruction: instruction)
                                .padding(.horizontal, 24)
                                .padding(.top, 16)
                                .padding(.bottom, 12)
                        } else {
                            // Mostrar "Tema libre" si no hay instrucción específica
                            FreeTopicView()
                                .padding(.horizontal, 24)
                                .padding(.top, 16)
                                .padding(.bottom, 12)
                        }
                        
                    // Indicador de progreso de días
                    DayProgressView(
                        days: viewModel.days,
                        selectedDay: $viewModel.currentDay,
                        dayStatuses: viewModel.days.map { viewModel.getDayStatus($0) },
                        devotional: devotional,
                        onDaySelected: { day in
                            Task {
                                await viewModel.loadMessages(for: day)
                            }
                        }
                    )
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                        
                        // Resumen de progreso
                        ProgressSummaryView(
                            currentDay: viewModel.currentDay,
                            totalDays: 7,
                            missedDays: viewModel.getMissedDaysCount()
                        )
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                        
                        // Chat de mensajes
                        DevotionalChatView(
                            messages: viewModel.messages,
                            currentUserId: viewModel.currentUserId ?? "",
                            onEditMessage: { message in
                                viewModel.userMessage = message
                                showMessageComposer = true
                            }
                        )
                        .frame(minHeight: 300)
                    }
                }
                .background(Color.screenBG.ignoresSafeArea())
                .overlay(alignment: .bottomTrailing) {
                    // Botón flotante para enviar/editar mensaje
                    if viewModel.userMessage == nil || viewModel.getDayStatus(viewModel.currentDay) == .current {
                        FloatingActionButton {
                            showMessageComposer = true
                        }
                        .padding(20)
                    }
                }
            } else {
                // No hay devocional activo
                VStack(spacing: 16) {
                    NoDevotionalView()
                    
                    // Botón de refresh para debug
                    Button {
                        Task {
                            print("🔄 [DevotionalView] Refresh manual presionado")
                            await viewModel.loadDevotional(teamId: teamId)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Recargar")
                        }
                        .padding()
                        .background(Color.accentBrand)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
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
            print("📱 [DevotionalView] Iniciando carga del devocional para teamId: \(teamId)")
            await viewModel.loadDevotional(teamId: teamId)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DevotionalCreated"))) { notification in
            let notificationTeamId = notification.userInfo?["teamId"] as? String
            print("📢 [DevotionalView] Notificación DevotionalCreated recibida")
            print("   TeamId en notificación: \(notificationTeamId ?? "ninguno")")
            print("   TeamId de esta vista: \(teamId)")
            
            // Solo recargar si el teamId coincide o si no hay teamId en la notificación
            if notificationTeamId == nil || notificationTeamId == teamId {
                Task {
                    print("🔄 [DevotionalView] Recargando devocional para teamId: \(teamId)")
                    await viewModel.loadDevotional(teamId: teamId)
                }
            } else {
                print("⏭️ [DevotionalView] Ignorando notificación (teamId diferente)")
            }
        }
        .onAppear {
            print("👁️ [DevotionalView] Vista apareció, teamId: \(teamId)")
            print("   Devocional actual: \(viewModel.devotional?.title ?? "ninguno")")
        }
    }
}

// MARK: - Devotional Header View

struct DevotionalHeaderView: View {
    let devotional: DevotionalEntity
    
    var body: some View {
        VStack(spacing: 8) {
            // Nombre del devocional centrado
            Text(devotional.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.primaryText)
            
            // Rango de fechas
            Text(dateRangeText)
                .font(.system(size: 16))
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .background(Color.white)
    }
    
    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d"
        let startDay = formatter.string(from: devotional.startDate)
        
        formatter.dateFormat = "d 'de' MMMM"
        let endDate = formatter.string(from: devotional.endDate)
        
        return "\(startDay) al \(endDate)"
    }
}

// MARK: - Daily Instruction View

struct DailyInstructionView: View {
    let instruction: DailyInstruction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(instruction.instruction)
                .font(.system(size: 15))
                .foregroundStyle(Color.secondaryText)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }
}

// MARK: - Day Progress View

struct DayProgressView: View {
    let days: [Int]
    @Binding var selectedDay: Int
    let dayStatuses: [DayStatus]
    let devotional: DevotionalEntity
    let onDaySelected: (Int) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(days, id: \.self) { day in
                    DayButton(
                        day: day,
                        status: dayStatuses[day - 1],
                        isSelected: selectedDay == day,
                        devotional: devotional
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
    let devotional: DevotionalEntity
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    // Caja cuadrada
                    RoundedRectangle(cornerRadius: 8)
                        .fill(backgroundColor)
                        .frame(width: 60, height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.accentBrand : borderColor, lineWidth: isSelected ? 3 : 1)
                        )
                    
                    // Indicador de estado en la esquina superior derecha
                    if status == .completed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                            .padding(4)
                    } else if status == .missed {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                            .padding(4)
                    }
                    
                    // Fecha del día (día del mes)
                    Text(dayDateNumber)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(textColor)
                }
                
                // Texto de estado (no mostrar si es future/pending)
                if status != .pending {
                    Text(statusText)
                        .font(.caption2)
                        .foregroundStyle(statusColor)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var backgroundColor: Color {
        switch status {
        case .completed:
            return Color.green.opacity(0.15)
        case .current:
            return Color.white
        case .missed:
            return Color.white
        case .pending:
            return Color.gray.opacity(0.1)
        }
    }
    
    private var borderColor: Color {
        switch status {
        case .completed:
            return Color.green.opacity(0.3)
        case .current:
            return Color.accentBrand
        case .missed:
            return Color.orange.opacity(0.3)
        case .pending:
            return Color.gray.opacity(0.3)
        }
    }
    
    private var textColor: Color {
        switch status {
        case .completed:
            return .green
        case .current:
            return .accentBrand
        case .missed:
            return .orange
        case .pending:
            return .secondaryText
        }
    }
    
    private var dayDateNumber: String {
        // Calcular la fecha del día basado en el devocional y obtener el día del mes
        let calendar = Calendar.current
        if let dayDate = calendar.date(byAdding: .day, value: day - 1, to: devotional.startDate) {
            let dayOfMonth = calendar.component(.day, from: dayDate)
            return "\(dayOfMonth)"
        }
        return "\(day)"
    }
    
    private var statusText: String {
        switch status {
        case .completed:
            return NSLocalizedString("completed", comment: "")
        case .missed:
            return NSLocalizedString("missed", comment: "")
        case .current:
            return NSLocalizedString("current", comment: "")
        case .pending:
            return "" // No mostrar nada para future
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .completed:
            return Color.green
        case .missed:
            return Color.orange
        case .current:
            return Color.accentBrand
        case .pending:
            return Color.gray
        }
    }
}

// MARK: - Progress Summary View

struct ProgressSummaryView: View {
    let currentDay: Int
    let totalDays: Int
    let missedDays: Int
    
    var body: some View {
        HStack {
            Text("Día \(currentDay) de \(totalDays)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.primaryText)
            
            Spacer()
            
            if missedDays > 0 {
                Text("\(missedDays) Días perdidos")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.orange)
            }
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
            ZStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 56, height: 56)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}
