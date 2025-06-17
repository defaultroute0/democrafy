import Foundation
import Combine

class LobbyViewModel: ObservableObject {
    @Published var rooms: [PartyRoom] = []
    private let backend: PartyBackendService
    private var cancellables = Set<AnyCancellable>()

    init(backendService: PartyBackendService) {
        self.backend = backendService
        fetchRooms()
    }

    func fetchRooms() {
        backend.fetchRooms()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { self.rooms = $0 })
            .store(in: &cancellables)
    }

    func createRoom() {
        let name = "Room \(Int.random(in: 1000...9999))"
        backend.createRoom(name: name)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { self.rooms.append($0) })
            .store(in: &cancellables)
    }
}
