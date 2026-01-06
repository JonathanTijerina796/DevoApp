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
    private let createTeamUseCase: CreateTeamUseCaseProtocol
    private let joinTeamUseCase: JoinTeamUseCaseProtocol
    private let getUserTeamUseCase: GetUserTeamUseCaseProtocol
    
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
        
        do {
            let team = try await createTeamUseCase.execute(
                name: name,
                leaderId: user.uid,
                leaderName: leaderName
            )
            
            currentTeam = team
            isLoading = false
            return team
            
        } catch {
            isLoading = false
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
        
        do {
            let team = try await joinTeamUseCase.execute(code: code, userId: user.uid)
            currentTeam = team
            isLoading = false
            return true
            
        } catch {
            isLoading = false
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }
    
    // MARK: - Load User Team
    
    func loadCurrentUserTeam() async {
        guard let user = Auth.auth().currentUser else {
            return
        }
        
        isLoading = true
        
        do {
            currentTeam = try await getUserTeamUseCase.execute(userId: user.uid)
            isLoading = false
            
        } catch {
            isLoading = false
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

