import SwiftUI

@main
struct DemocrafyApp: App {
    @StateObject private var authService = SpotifyAuthService()
    @StateObject private var apiService: SpotifyAPIService
    @StateObject private var backendService = PartyBackendService(baseURL: Config.backendURL)

    init() {
        let auth = SpotifyAuthService()
        _authService = StateObject(wrappedValue: auth)
        _apiService = StateObject(wrappedValue: SpotifyAPIService(authService: auth))
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                LobbyView()
            }
            .environmentObject(authService)
            .environmentObject(apiService)
            .environmentObject(backendService)
        }
    }
}
