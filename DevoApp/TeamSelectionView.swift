import SwiftUI

struct TeamSelectionView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showLeaderRegistration = false
    @State private var showMemberRegistration = false
    
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
                            showLeaderRegistration = true
                        }
                        
                        // Botón Integrante
                        TeamOptionCard(
                            title: NSLocalizedString("i_am_member", comment: ""),
                            description: NSLocalizedString("member_description", comment: ""),
                            icon: "person.2.fill",
                            color: Color.secondaryBrand
                        ) {
                            showMemberRegistration = true
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
            .sheet(isPresented: $showLeaderRegistration) {
                LeaderRegistrationView()
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showMemberRegistration) {
                MemberRegistrationView()
                    .environmentObject(authManager)
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
    @StateObject private var viewModel = DependencyContainer.shared.makeTeamViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var teamName: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showSuccessAlert = false
    @State private var createdTeamCode = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.accentBrand)
                        
                        Text(NSLocalizedString("register_as_leader", comment: ""))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color.primaryText)
                        
                        Text(NSLocalizedString("register_leader_description", comment: ""))
                            .font(.system(size: 16))
                            .foregroundStyle(Color.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 40)
                    
                    // Campo de nombre del equipo
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("team_name", comment: ""))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.primaryText)
                        
                        AppTextField(
                            text: $teamName,
                            placeholder: NSLocalizedString("enter_team_name", comment: "")
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    
                    // Botón de acción
                    Button {
                        Task {
                            await handleRegistration()
                        }
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            Text(NSLocalizedString("register_team", comment: ""))
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.accentBrand)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading || teamName.isEmpty)
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
                        dismiss()
                    }
                    .foregroundStyle(Color.accentBrand)
                }
            }
            .alert("Error", isPresented: $showAlert) {
                Button("OK") {
                    viewModel.errorMessage = ""
                }
            } message: {
                Text(alertMessage)
            }
            .alert(NSLocalizedString("team_created_success", comment: ""), isPresented: $showSuccessAlert) {
                Button(NSLocalizedString("continue", comment: "")) {
                    dismiss()
                }
            } message: {
                Text(NSLocalizedString("team_created_message", comment: "").replacingOccurrences(of: "{code}", with: createdTeamCode))
            }
        }
    }
    
    private func handleRegistration() async {
        if let team = await viewModel.createTeam(name: teamName) {
            createdTeamCode = team.code
            showSuccessAlert = true
        } else {
            alertMessage = viewModel.errorMessage
            showAlert = true
        }
    }
}

// MARK: - Member Registration View

struct MemberRegistrationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var viewModel = DependencyContainer.shared.makeTeamViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var teamCode: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showSuccessAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.secondaryBrand)
                        
                        Text(NSLocalizedString("join_team", comment: ""))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color.primaryText)
                        
                        Text(NSLocalizedString("join_team_description", comment: ""))
                            .font(.system(size: 16))
                            .foregroundStyle(Color.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 40)
                    
                    // Campo de código del equipo
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("team_code", comment: ""))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.primaryText)
                        
                        AppTextField(
                            text: $teamCode,
                            placeholder: NSLocalizedString("enter_team_code", comment: "")
                        )
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    
                    // Botón de acción
                    Button {
                        Task {
                            await handleJoinTeam()
                        }
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            Text(NSLocalizedString("join_team_button", comment: ""))
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.secondaryBrand)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading || teamCode.isEmpty)
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
                        dismiss()
                    }
                    .foregroundStyle(Color.accentBrand)
                }
            }
            .alert("Error", isPresented: $showAlert) {
                Button("OK") {
                    viewModel.errorMessage = ""
                }
            } message: {
                Text(alertMessage)
            }
            .alert(NSLocalizedString("team_joined_success", comment: ""), isPresented: $showSuccessAlert) {
                Button(NSLocalizedString("continue", comment: "")) {
                    dismiss()
                }
            } message: {
                if let team = viewModel.currentTeam {
                    Text(NSLocalizedString("team_joined_message", comment: "").replacingOccurrences(of: "{name}", with: team.name))
                }
            }
        }
    }
    
    private func handleJoinTeam() async {
        let success = await viewModel.joinTeam(code: teamCode)
        
        if success {
            showSuccessAlert = true
        } else {
            alertMessage = viewModel.errorMessage
            showAlert = true
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

