import SwiftUI

// MARK: - Active Sheet Enum
// Solución para manejar múltiples sheets sin conflictos

enum ActiveSheet: Identifiable {
    case leader
    case member
    
    var id: String {
        switch self {
        case .leader: return "leader"
        case .member: return "member"
        }
    }
}

struct TeamSelectionView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var activeSheet: ActiveSheet?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Logo
                    Image("DevoLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 150)
                        .padding(.top, 40)
                    
                    // Título principal
                    Text(NSLocalizedString("find_your_team", comment: ""))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.primaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    // Subtítulo
                    Text(NSLocalizedString("find_team_subtitle", comment: ""))
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 8)
                    
                    // Opciones
                    VStack(spacing: 16) {
                        // Botón Líder
                        TeamOptionCard(
                            title: NSLocalizedString("i_am_leader", comment: ""),
                            description: NSLocalizedString("leader_description", comment: ""),
                            icon: "person.crop.circle.badge.checkmark",
                            color: Color.accentBrand
                        ) {
                            activeSheet = .leader
                        }
                        
                        // Botón Integrante
                        TeamOptionCard(
                            title: NSLocalizedString("i_am_member", comment: ""),
                            description: NSLocalizedString("member_description", comment: ""),
                            icon: "person.2.fill",
                            color: Color.secondaryBrand
                        ) {
                            activeSheet = .member
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    
                    Spacer(minLength: 40)
                }
                .frame(maxWidth: .infinity)
            }
            .background(Color.screenBG.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .leader:
                    LeaderRegistrationView(
                        onFinished: { activeSheet = nil }
                    )
                    .environmentObject(authManager)
                case .member:
                    MemberRegistrationView(
                        onFinished: { activeSheet = nil }
                    )
                    .environmentObject(authManager)
                }
            }
        }
    }
}

// MARK: - Team Option Card

private struct TeamOptionCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icono
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(color)
                    .frame(width: 50, height: 50)
                
                // Texto
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.primaryText)
                    
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Flecha
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.secondaryText)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Leader Registration View

struct LeaderRegistrationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var viewModel = TeamViewModel(
        createTeamUseCase: DependencyContainer.shared.createTeamUseCase,
        joinTeamUseCase: DependencyContainer.shared.joinTeamUseCase,
        getUserTeamUseCase: DependencyContainer.shared.getUserTeamUseCase
    )
    let onFinished: () -> Void
    @State private var teamName: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        RegistrationFormView(
            icon: "person.crop.circle.badge.checkmark",
            iconColor: Color.accentBrand,
            title: NSLocalizedString("register_as_leader", comment: ""),
            description: NSLocalizedString("register_leader_description", comment: ""),
            fieldLabel: NSLocalizedString("team_name", comment: ""),
            fieldPlaceholder: NSLocalizedString("enter_team_name", comment: ""),
            buttonText: NSLocalizedString("register_team", comment: ""),
            buttonColor: Color.accentBrand,
            text: $teamName,
            isLoading: viewModel.isLoading,
            onAction: { await handleRegistration() },
            onCancel: onFinished,
            showAlert: $showAlert,
            alertMessage: $alertMessage
        )
        .onDisappear {
            NotificationCenter.default.post(name: NSNotification.Name("TeamUpdated"), object: nil)
        }
    }
    
    private func handleRegistration() async {
        if let _ = await viewModel.createTeam(name: teamName) {
            NotificationCenter.default.post(name: NSNotification.Name("TeamCreated"), object: nil)
            await MainActor.run { onFinished() }
        } else {
            await MainActor.run {
                alertMessage = viewModel.errorMessage
                showAlert = true
            }
        }
    }
}

// MARK: - Member Registration View

struct MemberRegistrationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var viewModel = TeamViewModel(
        createTeamUseCase: DependencyContainer.shared.createTeamUseCase,
        joinTeamUseCase: DependencyContainer.shared.joinTeamUseCase,
        getUserTeamUseCase: DependencyContainer.shared.getUserTeamUseCase
    )
    let onFinished: () -> Void
    @State private var teamCode: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        RegistrationFormView(
            icon: "person.2.fill",
            iconColor: Color.secondaryBrand,
            title: NSLocalizedString("join_team", comment: ""),
            description: NSLocalizedString("join_team_description", comment: ""),
            fieldLabel: NSLocalizedString("team_code", comment: ""),
            fieldPlaceholder: NSLocalizedString("enter_team_code", comment: ""),
            buttonText: NSLocalizedString("join_team_button", comment: ""),
            buttonColor: Color.secondaryBrand,
            text: $teamCode,
            isLoading: viewModel.isLoading,
            onAction: { await handleJoinTeam() },
            onCancel: onFinished,
            showAlert: $showAlert,
            alertMessage: $alertMessage
        )
        .onDisappear {
            NotificationCenter.default.post(name: NSNotification.Name("TeamUpdated"), object: nil)
        }
    }
    
    private func handleJoinTeam() async {
        if await viewModel.joinTeam(code: teamCode) {
            NotificationCenter.default.post(name: NSNotification.Name("TeamJoined"), object: nil)
            await MainActor.run { onFinished() }
        } else {
            await MainActor.run {
                alertMessage = viewModel.errorMessage
                showAlert = true
            }
        }
    }
}

// MARK: - Shared Registration Form Component

private struct RegistrationFormView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let fieldLabel: String
    let fieldPlaceholder: String
    let buttonText: String
    let buttonColor: Color
    @Binding var text: String
    let isLoading: Bool
    let onAction: () async -> Void
    let onCancel: () -> Void
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.system(size: 60))
                            .foregroundStyle(iconColor)
                        
                        Text(title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color.primaryText)
                        
                        Text(description)
                            .font(.system(size: 16))
                            .foregroundStyle(Color.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 40)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(fieldLabel)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.primaryText)
                        
                        AppTextField(text: $text, placeholder: fieldPlaceholder)
                            .textInputAutocapitalization(icon == "person.2.fill" ? .characters : .none)
                            .autocorrectionDisabled(true)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    
                    Button {
                        Task { await onAction() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            Text(buttonText)
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(buttonColor)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || text.isEmpty)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    Spacer()
                }
            }
            .background(Color.screenBG.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("cancel", comment: "")) {
                        onCancel()
                    }
                    .foregroundStyle(Color.accentBrand)
                }
            }
            .alert("Error", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
}

// MARK: - Theme Extension

private extension Color {
    static let secondaryBrand = Color(red: 0.4, green: 0.6, blue: 0.9)
}

// MARK: - Preview

#Preview {
    TeamSelectionView()
        .environmentObject(AuthenticationManager())
}

