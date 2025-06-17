import Foundation
import Combine

class PlayerViewModel: ObservableObject {
    @Published var devices: [SpotifyDevice] = []
    @Published var selectedDeviceID: String?
    private let api: SpotifyAPIService
    private let backend: PartyBackendService
    private var cancellables = Set<AnyCancellable>()

    init(apiService: SpotifyAPIService, backendService: PartyBackendService) {
        self.api = apiService
        self.backend = backendService
        fetchDevices()
    }

    func fetchDevices() {
        api.fetchDevices()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { self.devices = $0; self.selectedDeviceID = $0.first?.id })
            .store(in: &cancellables)
    }

    func transferPlayback(play: Bool = true) {
        guard let id = selectedDeviceID else { return }
        api.transferPlayback(to: id)
            .sink(receiveCompletion: { _ in }, receiveValue: {})
            .store(in: &cancellables)
    }

    func enqueueNext(roomID: String) {
        backend.fetchTopSuggestion(roomID: roomID)
            .flatMap { sug in self.api.enqueueTrack(uri: sug.uri) }
            .sink(receiveCompletion: { _ in }, receiveValue: {})
            .store(in: &cancellables)
    }

    func skip() {
        api.skipToNext()
            .sink(receiveCompletion: { _ in }, receiveValue: {})
            .store(in: &cancellables)
    }
}
