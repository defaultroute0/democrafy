import Foundation

struct Config {
    // Backend Configuration
    static let backendURL = URL(string: ProcessInfo.processInfo.environment["BACKEND_URL"] ?? "http://localhost:3000")!
    
    // Spotify Configuration
    static let spotifyClientID = ProcessInfo.processInfo.environment["SPOTIFY_CLIENT_ID"] ?? ""
    static let redirectURI = URL(string: "democrafy://callback")!
    static let scopes = [
        "user-read-playback-state",
        "user-modify-playback-state",
        "playlist-modify-private",
        "user-read-currently-playing"
    ]
}
