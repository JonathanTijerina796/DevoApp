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
        print("🎯 [TeamViewModel] createTeam llamado con nombre: \(name)")
        
        guard let user = Auth.auth().currentUser else {
            print("❌ [TeamViewModel] Usuario no autenticado")
            errorMessage = NSLocalizedString("user_not_authenticated", comment: "")
            return nil
        }
        
        let leaderName = user.displayName ?? user.email ?? "Usuario"
        print("👤 [TeamViewModel] Usuario autenticado: \(user.uid), nombre: \(leaderName)")
        
        isLoading = true
        errorMessage = ""
        print("🔄 [TeamViewModel] isLoading = true")
        
        do {
            print("🚀 [TeamViewModel] Ejecutando CreateTeamUseCase...")
            let team = try await createTeamUseCase.execute(
                name: name,
                leaderId: user.uid,
                leaderName: leaderName
            )
            
            print("✅ [TeamViewModel] UseCase completado exitosamente")
            print("   - Equipo: \(team.name), código: \(team.code), ID: \(team.id ?? "nil")")
            
            currentTeam = team
            isLoading = false
            print("🔄 [TeamViewModel] isLoading = false, currentTeam actualizado")
            
            return team
            
        } catch {
            isLoading = false
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            print("❌ [TeamViewModel] Error en UseCase:")
            print("   - Error: \(errorMessage)")
            print("   - Tipo: \(type(of: error))")
            print("🔄 [TeamViewModel] isLoading = false después del error")
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

