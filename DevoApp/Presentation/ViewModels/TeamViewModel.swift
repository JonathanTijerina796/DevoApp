import Foundation
import FirebaseAuth

// MARK: - Team ViewModel
// ViewModel que coordina los casos de uso y expone datos para la UI

@MainActor
final class TeamViewModel: ObservableObject {
    @Published var currentTeam: TeamEntity?
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // Dependency Injection - dependemos de abstracciones (protocolos)
    // No aisladas al MainActor para permitir inicialización desde cualquier contexto
    nonisolated(unsafe) private let createTeamUseCase: CreateTeamUseCaseProtocol
    nonisolated(unsafe) private let joinTeamUseCase: JoinTeamUseCaseProtocol
    nonisolated(unsafe) private let getUserTeamUseCase: GetUserTeamUseCaseProtocol
    
    nonisolated init(
        createTeamUseCase: CreateTeamUseCaseProtocol,
        joinTeamUseCase: JoinTeamUseCaseProtocol,
        getUserTeamUseCase: GetUserTeamUseCaseProtocol
    ) {
        self.createTeamUseCase = createTeamUseCase
        self.joinTeamUseCase = joinTeamUseCase
        self.getUserTeamUseCase = getUserTeamUseCase
    }
    
    // MARK: - Create Team
    
    func createTeam(name: String) async -> TeamEntity? {
        guard let user = Auth.auth().currentUser else {
            errorMessage = NSLocalizedString("user_not_authenticated", comment: "")
            return nil
        }
        
        let leaderName = user.displayName ?? user.email ?? "Usuario"
        isLoading = true
        errorMessage = ""
        
        defer { isLoading = false }
        
        do {
            let team = try await createTeamUseCase.execute(
                name: name,
                leaderId: user.uid,
                leaderName: leaderName
            )
            currentTeam = team
            try await Task.sleep(nanoseconds: 2_000_000_000) // Delay de 2 segundos
            return team
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }
    
    // MARK: - Join Team
    
    func joinTeam(code: String) async -> Bool {
        guard let user = Auth.auth().currentUser else {
            errorMessage = NSLocalizedString("user_not_authenticated", comment: "")
            return false
        }
        
        isLoading = true
        errorMessage = ""
        
        defer { isLoading = false }
        
        do {
            let team = try await joinTeamUseCase.execute(code: code, userId: user.uid)
            currentTeam = team
            try await Task.sleep(nanoseconds: 2_000_000_000) // Delay de 2 segundos
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }
    
    // MARK: - Load User Team
    
    func loadCurrentUserTeam() async {
        guard let user = Auth.auth().currentUser else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            currentTeam = try await getUserTeamUseCase.execute(userId: user.uid)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

