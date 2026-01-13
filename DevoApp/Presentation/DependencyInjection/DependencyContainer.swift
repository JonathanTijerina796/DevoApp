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
    
    lazy var devotionalRepository: DevotionalRepositoryProtocol = {
        DevotionalRepository(db: Firestore.firestore())
    }()
    
    // MARK: - Use Cases
    
    lazy var createTeamUseCase: CreateTeamUseCaseProtocol = {
        CreateTeamUseCase(
            teamRepository: teamRepository,
            userRepository: userRepository,
            createDefaultDevotionalUseCase: createDefaultDevotionalUseCase
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
    
    lazy var getUserTeamsUseCase: GetUserTeamsUseCaseProtocol = {
        GetUserTeamsUseCase(
            userRepository: userRepository,
            teamRepository: teamRepository
        )
    }()
    
    // Devotional Use Cases
    lazy var getActiveDevotionalUseCase: GetActiveDevotionalUseCaseProtocol = {
        GetActiveDevotionalUseCase(devotionalRepository: devotionalRepository)
    }()
    
    lazy var sendDevotionalMessageUseCase: SendDevotionalMessageUseCaseProtocol = {
        SendDevotionalMessageUseCase(devotionalRepository: devotionalRepository)
    }()
    
    lazy var getDevotionalMessagesUseCase: GetDevotionalMessagesUseCaseProtocol = {
        GetDevotionalMessagesUseCase(devotionalRepository: devotionalRepository)
    }()
    
    lazy var getUserDevotionalMessageUseCase: GetUserDevotionalMessageUseCaseProtocol = {
        GetUserDevotionalMessageUseCase(devotionalRepository: devotionalRepository)
    }()
    
    lazy var createDefaultDevotionalUseCase: CreateDefaultDevotionalUseCaseProtocol = {
        CreateDefaultDevotionalUseCase(devotionalRepository: devotionalRepository)
    }()
    
    lazy var createDevotionalUseCase: CreateDevotionalUseCaseProtocol = {
        CreateDevotionalUseCase(
            devotionalRepository: devotionalRepository,
            teamRepository: teamRepository
        )
    }()
    
    // MARK: - ViewModels
    
    func makeTeamViewModel() -> TeamViewModel {
        TeamViewModel(
            createTeamUseCase: createTeamUseCase,
            joinTeamUseCase: joinTeamUseCase,
            getUserTeamUseCase: getUserTeamUseCase
        )
    }
    
    func makeDevotionalViewModel() -> DevotionalViewModel {
        DevotionalViewModel(
            getActiveDevotionalUseCase: getActiveDevotionalUseCase,
            sendMessageUseCase: sendDevotionalMessageUseCase,
            getMessagesUseCase: getDevotionalMessagesUseCase,
            getUserMessageUseCase: getUserDevotionalMessageUseCase,
            devotionalRepository: devotionalRepository
        )
    }
}

