import Foundation
import FirebaseFirestore

// MARK: - Dependency Container
// Centraliza la creación de dependencias y aplica Dependency Injection

final class DependencyContainer {
    static let shared = DependencyContainer()
    
    private init() {}
    
    // MARK: - Repositories
    
    lazy var teamRepository: TeamRepositoryProtocol = {
        TeamRepository(db: Firestore.firestore())
    }()
    
    lazy var userRepository: UserRepositoryProtocol = {
        UserRepository(db: Firestore.firestore())
    }()
    
    // MARK: - Use Cases
    
    lazy var createTeamUseCase: CreateTeamUseCaseProtocol = {
        CreateTeamUseCase(
            teamRepository: teamRepository,
            userRepository: userRepository
        )
    }()
    
    lazy var joinTeamUseCase: JoinTeamUseCaseProtocol = {
        JoinTeamUseCase(
            teamRepository: teamRepository,
            userRepository: userRepository
        )
    }()
    
    lazy var getUserTeamUseCase: GetUserTeamUseCaseProtocol = {
        GetUserTeamUseCase(
            userRepository: userRepository,
            teamRepository: teamRepository
        )
    }()
    
    lazy var deleteTeamUseCase: DeleteTeamUseCaseProtocol = {
        DeleteTeamUseCase(
            teamRepository: teamRepository,
            userRepository: userRepository
        )
    }()
    
    // MARK: - ViewModels
    
    func makeTeamViewModel() -> TeamViewModel {
        TeamViewModel(
            createTeamUseCase: createTeamUseCase,
            joinTeamUseCase: joinTeamUseCase,
            getUserTeamUseCase: getUserTeamUseCase,
            deleteTeamUseCase: deleteTeamUseCase
        )
    }
}

