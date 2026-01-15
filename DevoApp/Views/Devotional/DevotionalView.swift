import SwiftUI

// MARK: - Devotional View
// Vista principal del devocional con chat tipo WhatsApp

struct DevotionalView: View {
    @StateObject private var viewModel: DevotionalViewModel
    @EnvironmentObject var teamManager: TeamManager
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showMessageComposer = false
    @State private var showCreateDevotional = false
    let teamId: String
    
    init(teamId: String, viewModel: DevotionalViewModel) {
        self.teamId = teamId
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    private var isLeader: Bool {
        guard let team = teamManager.currentTeam,
              let userId = authManager.user?.uid else {
            return false
        }
        return team.leaderId == userId
    }
    
    private func cleanupExpiredDevotionalsIfNeeded() async {
        // Verificar si ya se ejecutó la limpieza hoy
        let lastCleanupKey = "lastDevotionalCleanup"
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastCleanupDate = UserDefaults.standard.object(forKey: lastCleanupKey) as? Date {
            let lastCleanupDay = calendar.startOfDay(for: lastCleanupDate)
            if lastCleanupDay == today {
                // Ya se ejecutó hoy, no hacer nada
                return
            }
        }
        
        // Ejecutar limpieza
        await teamManager.cleanupExpiredDevotionals()
        
        // Guardar fecha de última limpieza
        UserDefaults.standard.set(Date(), forKey: lastCleanupKey)
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
                            // Si la "instrucción" realmente es Tema Libre, mostrar la tarjeta de tema libre (con botón)
                            // Esto evita que el devocional default bloquee la UI de crear tema.
                            if instruction.instruction == NSLocalizedString("free_topic_instruction", comment: "") {
                                FreeTopicView(
                                    showCreateButton: isLeader,
                                    onCreateDevotional: { showCreateDevotional = true }
                                )
                                .padding(.horizontal, 24)
                                .padding(.top, 16)
                                .padding(.bottom, 12)
                            } else {
                                DailyInstructionView(instruction: instruction)
                                    .padding(.horizontal, 24)
                                    .padding(.top, 16)
                                    .padding(.bottom, 12)
                            }
                        } else {
                            // Mostrar "Tema libre" si no hay instrucción específica
                            FreeTopicView(
                                showCreateButton: isLeader,
                                onCreateDevotional: { showCreateDevotional = true }
                            )
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
                NoDevotionalView(
                    teamId: teamId,
                    teamName: teamManager.currentTeam?.name ?? "",
                    isLeader: isLeader,
                    onCreateTopic: {
                        showCreateDevotional = true
                    }
                )
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
            // Limpiar devocionales vencidos antes de cargar (solo una vez al día)
            await cleanupExpiredDevotionalsIfNeeded()
            await viewModel.loadDevotional(teamId: teamId)
        }
        .onChange(of: teamId) { oldValue, newValue in
            // Cuando cambia el teamId, resetear y recargar el devocional
            print("🔄 [DevotionalView] teamId cambió: \(oldValue) -> \(newValue)")
            Task {
                // Resetear el estado del ViewModel
                await viewModel.reset()
                // Cargar el nuevo devocional
                await viewModel.loadDevotional(teamId: newValue)
            }
        }
        .onChange(of: teamManager.currentTeam?.id) { oldValue, newValue in
            // También observar cambios en el equipo actual del TeamManager
            if let newTeamId = newValue, newTeamId != teamId {
                print("🔄 [DevotionalView] currentTeam cambió: \(oldValue ?? "nil") -> \(newValue ?? "nil")")
                Task {
                    // Resetear el estado del ViewModel
                    await viewModel.reset()
                    // Cargar el nuevo devocional
                    await viewModel.loadDevotional(teamId: newTeamId)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TeamSwitched"))) { notification in
            let notificationTeamId = notification.userInfo?["teamId"] as? String
            print("📢 [DevotionalView] Notificación TeamSwitched recibida")
            print("   TeamId en notificación: \(notificationTeamId ?? "ninguno")")
            print("   TeamId de esta vista: \(teamId)")
            
            // Si el teamId de la notificación coincide con el de esta vista, recargar
            if let notificationTeamId = notificationTeamId, notificationTeamId == teamId {
                Task {
                    print("🔄 [DevotionalView] Recargando devocional después de cambio de equipo para teamId: \(teamId)")
                    await viewModel.reset()
                    await viewModel.loadDevotional(teamId: teamId)
                }
            }
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
        .sheet(isPresented: $showCreateDevotional) {
            if let team = teamManager.currentTeam, let teamId = team.id {
                CreateDevotionalView(teamId: teamId, teamName: team.name)
            }
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
    let showCreateButton: Bool
    let onCreateDevotional: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("free_topic", comment: ""))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.accentBrand)
                
                Text(NSLocalizedString("free_topic_description", comment: ""))
                    .font(.system(size: 16))
                    .foregroundStyle(Color.primaryText)
            }
            
            Divider()
                .padding(.vertical, 4)
            
            if showCreateButton {
                // Botón para crear devocional
                Button {
                    onCreateDevotional()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                        Text(NSLocalizedString("create_devotional", comment: ""))
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentBrand)
                    .cornerRadius(10)
                    .shadow(color: Color.accentBrand.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentBrand.opacity(0.1))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - No Devotional View

struct NoDevotionalView: View {
    let teamId: String
    let teamName: String
    let isLeader: Bool
    let onCreateTopic: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "book.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(Color.secondaryText)
                    .padding(.top, 40)
                
                Text(NSLocalizedString("no_active_devotional", comment: ""))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.primaryText)
                
                Text(NSLocalizedString("no_devotional_description", comment: ""))
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                // Solo mostrar botones si es líder
                if isLeader {
                    VStack(spacing: 16) {
                        // Opción para crear tema
                        Button {
                            onCreateTopic()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                Text("Add New Topic")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentBrand)
                            .cornerRadius(12)
                        }
                        
                        // Opción para usar tema libre
                        Button {
                            // Crear devocional con tema libre
                            Task {
                                await createFreeTopicDevotional()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 20))
                                Text("Use Free Topic")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.accentBrand)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentBrand.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.accentBrand, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
    
    private func createFreeTopicDevotional() async {
        // Crear devocional por defecto con tema libre
        do {
            let useCase = DependencyContainer.shared.createDefaultDevotionalUseCase
            _ = try await useCase.execute(teamId: teamId, teamName: teamName)
            // Notificar que se creó un devocional
            NotificationCenter.default.post(name: NSNotification.Name("DevotionalCreated"), object: nil)
        } catch {
            print("Error al crear devocional de tema libre: \(error.localizedDescription)")
        }
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
