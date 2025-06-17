import Foundation

struct SpotifyDevice: Identifiable, Codable {
    let id: String
    let name: String
    let type: String
    let isActive: Bool
}
