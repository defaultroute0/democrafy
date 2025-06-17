import Foundation

struct Track: Identifiable, Codable {
    let id: String
    let uri: String
    let name: String
    let artist: String
    let albumArtURL: URL
}
