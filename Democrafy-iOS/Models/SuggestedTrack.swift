import Foundation

struct SuggestedTrack: Identifiable, Codable {
    let id: String
    let uri: String
    let title: String
    let artist: String
    let votes: Int
    let timestamp: Date
    var sortKey: VoteSortKey { VoteSortKey(votes: votes, timestamp: timestamp) }
}

struct VoteSortKey: Comparable {
    let votes: Int
    let timestamp: Date
    static func < (lhs: VoteSortKey, rhs: VoteSortKey) -> Bool {
        if lhs.votes != rhs.votes { return lhs.votes > rhs.votes }
        return lhs.timestamp < rhs.timestamp
    }
}
