import Foundation

struct Config {
    // Backend Configuration
    static let backendURL = URL(string: "http://localhost:3000")!
    
    // Spotify Configuration
    static let spotifyClientID = "809914f948534c97b01bbb0b81049b55"
    static let redirectURI = URL(string: "democrafy://callback")!
    static let scopes = [
        "user-read-playback-state",
        "user-modify-playback-state",
        "playlist-modify-private",
        "user-read-currently-playing"
    ]
}
