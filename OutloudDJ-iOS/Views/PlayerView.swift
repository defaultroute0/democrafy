import SwiftUI

struct PlayerView: View {
    @StateObject private var vm: PlayerViewModel
    let roomID: String

    init(roomID: String) {
        _vm = StateObject(wrappedValue: PlayerViewModel(apiService: SpotifyAPIService(authService: SpotifyAuthService()), backendService: PartyBackendService(baseURL: URL(string: "http://localhost:3000")!)))
        self.roomID = roomID
    }

    var body: some View {
        VStack(spacing: 20) {
            Picker("Device", selection: $vm.selectedDeviceID) {
                ForEach(vm.devices) { device in Text(device.name).tag(device.id as String?) }
            }
            .pickerStyle(MenuPickerStyle())

            Button("Connect & Play") { vm.transferPlayback() }

            HStack {
                Button(action: vm.skip) { Image(systemName: "forward.fill").font(.largeTitle) }
                Spacer()
                Button(action: { vm.enqueueNext(roomID: roomID) }) { Image(systemName: "plus.circle").font(.largeTitle) }
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Player")
        .onAppear { vm.fetchDevices() }
    }
}
