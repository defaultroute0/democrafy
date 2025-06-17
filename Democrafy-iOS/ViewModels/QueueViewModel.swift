import Foundation
import Combine

class QueueViewModel: ObservableObject {
    @Published var suggestions: [SuggestedTrack] = []
    private let backend: PartyBackendService
    private var cancellables = Set<AnyCancellable>()

    init(backendService: PartyBackendService) {
        self.backend = backendService
    }

    func fetchSuggestions(roomID: String) {
        backend.fetchSuggestions(roomID: roomID)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { self.suggestions = $0 })
            .store(in: &cancellables)
    }

    func vote(suggestionID: String, delta: Int) {
        backend.vote(suggestionID: suggestionID, delta: delta)
            .sink(receiveCompletion: { _ in }, receiveValue: {})
            .store(in: &cancellables)
    }
}
