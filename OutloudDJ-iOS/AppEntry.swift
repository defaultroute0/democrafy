import SwiftUI

@main
struct OutloudDJApp: App {
    @StateObject private var authService = SpotifyAuthService()
    @StateObject private var apiService: SpotifyAPIService
    @StateObject private var backendService = PartyBackendService(baseURL: URL(string: "http://localhost:3000")!)

    init() {
        let auth = SpotifyAuthService()
        _authService = StateObject(wrappedValue: auth)
        _apiService = StateObject(wrappedValue: SpotifyAPIService(authService: auth))
    }

    var body: some Scene {
        WindowGroup {
            NavigationView {
                LobbyView()
            }
            .environmentObject(authService)
            .environmentObject(apiService)
            .environmentObject(backendService)
        }
    }
}
