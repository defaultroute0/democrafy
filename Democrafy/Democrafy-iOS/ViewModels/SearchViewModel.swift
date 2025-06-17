import Foundation
import Combine

class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [Track] = []
    private let api: SpotifyAPIService
    private let backend: PartyBackendService
    private var cancellables = Set<AnyCancellable>()

    init(apiService: SpotifyAPIService, backendService: PartyBackendService) {
        self.api = apiService
        self.backend = backendService
        $query
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .flatMap { q in
                q.isEmpty ? Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
                         : apiService.searchTracks(query: q)
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { self.results = $0 })
            .store(in: &cancellables)
    }

    func suggest(track: Track, in room: PartyRoom) {
        backend.addSuggestion(roomID: room.id, track: track)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
}
