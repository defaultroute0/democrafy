import SwiftUI

struct LobbyView: View {
    @EnvironmentObject var backend: PartyBackendService
    @StateObject private var vm: LobbyViewModel

    init() {
        _vm = StateObject(wrappedValue: LobbyViewModel(backendService: PartyBackendService(baseURL: Config.backendURL)))
    }

    var body: some View {
        List(vm.rooms) { room in
            NavigationLink(destination: QueueView(room: room)) {
                Text(room.name)
            }
        }
        .navigationTitle("Party Rooms")
        .toolbar { Button(action: vm.createRoom) { Image(systemName: "plus.circle") } }
        .onAppear { vm.fetchRooms() }
    }
}
