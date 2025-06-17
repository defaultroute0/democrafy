import Foundation

struct PlaybackState: Codable {
    let isPlaying: Bool
    let progressMs: Int
    let item: Track?
}
