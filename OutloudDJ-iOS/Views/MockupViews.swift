import SwiftUI

struct MockupViews_Previews: PreviewProvider {
    static let sampleRooms = [PartyRoom(id: "1234", name: "Friday Night", hostUserID: "host1"), PartyRoom(id: "5678", name: "Office Party", hostUserID: "host2")]
    static let sampleTracks = [SuggestedTrack(id: "t1", uri: "", title: "Song A", artist: "Artist A", votes: 5, timestamp: Date()), SuggestedTrack(id: "t2", uri: "", title: "Song B", artist: "Artist B", votes: 2, timestamp: Date())]

    static var previews: some View {
        Group {
            NavigationView { LobbyView() }
                .previewDisplayName("Lobby Screen")
            NavigationView { SearchView(vm: SearchViewModel(apiService: SpotifyAPIService(authService: SpotifyAuthService()), backendService: PartyBackendService(baseURL: URL(string: "http://localhost:3000")!)), room: sampleRooms[0]) }
                .previewDisplayName("Search Screen")
            NavigationView { QueueView(room: sampleRooms[0]) }
                .previewDisplayName("Queue Screen")
            NavigationView { PlayerView(roomID: sampleRooms[0].id) }
                .previewDisplayName("Player Screen")
        }
        .previewLayout(.fixed(width: 375, height: 800))
    }
}
