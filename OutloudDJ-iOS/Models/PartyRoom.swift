import Foundation

struct PartyRoom: Identifiable, Codable {
    let id: String
    let name: String
    let hostUserID: String
}
