import SwiftUI

struct QueueView: View {
    let room: PartyRoom
    @StateObject private var vm: QueueViewModel

    init(room: PartyRoom) {
        self.room = room
        _vm = StateObject(wrappedValue: QueueViewModel(backendService: PartyBackendService(baseURL: Config.backendURL)))
    }

    var body: some View {
        List(vm.suggestions.sorted(by: { $0.sortKey < $1.sortKey })) { track in
            HStack {
                VStack(alignment: .leading) {
                    Text(track.title)
                    Text(track.artist).font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                HStack {
                    Button(action: { vm.vote(suggestionID: track.id, delta: 1) }) { Image(systemName: "arrow.up.circle") }
                    Text("\(track.votes)")
                    Button(action: { vm.vote(suggestionID: track.id, delta: -1) }) { Image(systemName: "arrow.down.circle") }
                }
            }
        }
        .navigationTitle(room.name)
        .toolbar { NavigationLink("Search", destination: SearchView(vm: SearchViewModel(apiService: SpotifyAPIService(authService: SpotifyAuthService()), backendService: PartyBackendService(baseURL: Config.backendURL)), room: room)) }
        .onAppear { vm.fetchSuggestions(roomID: room.id) }
    }
}
