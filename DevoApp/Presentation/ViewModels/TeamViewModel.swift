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
    nonisolated(unsafe) private let createTeamUseCase: CreateTeamUseCaseProtocol
    nonisolated(unsafe) private let joinTeamUseCase: JoinTeamUseCaseProtocol
    nonisolated(unsafe) private let getUserTeamUseCase: GetUserTeamUseCaseProtocol
    nonisolated(unsafe) private let deleteTeamUseCase: DeleteTeamUseCaseProtocol
    
    nonisolated init(
        createTeamUseCase: CreateTeamUseCaseProtocol,
        joinTeamUseCase: JoinTeamUseCaseProtocol,
        getUserTeamUseCase: GetUserTeamUseCaseProtocol,
        deleteTeamUseCase: DeleteTeamUseCaseProtocol
    ) {
        self.createTeamUseCase = createTeamUseCase
        self.joinTeamUseCase = joinTeamUseCase
        self.getUserTeamUseCase = getUserTeamUseCase
        self.deleteTeamUseCase = deleteTeamUseCase
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
    
    // MARK: - Delete Team
    
    func deleteTeam() async -> Bool {
        guard let user = Auth.auth().currentUser else {
            errorMessage = NSLocalizedString("user_not_authenticated", comment: "")
            return false
        }
        
        guard let teamId = currentTeam?.id else {
            errorMessage = NSLocalizedString("team_not_found", comment: "")
            return false
        }
        
        isLoading = true
        errorMessage = ""
        
        defer { isLoading = false }
        
        do {
            try await deleteTeamUseCase.execute(teamId: teamId, leaderId: user.uid)
            currentTeam = nil
            try await Task.sleep(nanoseconds: 2_000_000_000) // Delay de 2 segundos
            NotificationCenter.default.post(name: NSNotification.Name("TeamDeleted"), object: nil)
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }
}

