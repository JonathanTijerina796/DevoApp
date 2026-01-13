import Foundation
import FirebaseFirestore

struct Team: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var name: String
    var code: String
    var leaderId: String
    var leaderName: String
    var memberIds: [String]
    var createdAt: Timestamp
    var updatedAt: Timestamp
    
    init(id: String? = nil,
         name: String,
         code: String,
         leaderId: String,
         leaderName: String,
         memberIds: [String] = [],
         createdAt: Timestamp = Timestamp(),
         updatedAt: Timestamp = Timestamp()) {
        self.id = id
        self.name = name
        self.code = code
        self.leaderId = leaderId
        self.leaderName = leaderName
        self.memberIds = memberIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Equatable conformance
    static func == (lhs: Team, rhs: Team) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.code == rhs.code &&
               lhs.leaderId == rhs.leaderId &&
               lhs.leaderName == rhs.leaderName &&
               lhs.memberIds == rhs.memberIds
    }
}

