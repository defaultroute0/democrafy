import Foundation
import Combine
import os.log

private let logger = Logger(subsystem: "com.democrafy.app", category: "PartyBackendService")

class PartyBackendService: ObservableObject {
    @Published var error: Error?
    
    private let baseURL: URL
    private var cancellables = Set<AnyCancellable>()
    
    init(baseURL: URL = Config.baseURL) {
        self.baseURL = baseURL
    }
    
    private func request<T: Decodable>(path: String, method: String = "GET", body: Data? = nil) -> AnyPublisher<T, Error> {
        guard let url = baseURL.appendingPathComponent(path) else {
            return Fail(error: NSError(domain: "PartyBackendService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { response -> Data in
                guard let httpResponse = response.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    return response.data
                case 400:
                    throw NSError(domain: "PartyBackendService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Bad Request"])
                case 401:
                    throw NSError(domain: "PartyBackendService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])
                case 404:
                    throw NSError(domain: "PartyBackendService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Not Found"])
                default:
                    throw URLError(.badServerResponse)
                }
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    logger.error("Request failed: \(error.localizedDescription)")
                    self?.error = error
                }
            })
            .eraseToAnyPublisher()
    }

    func createRoom(name: String) -> AnyPublisher<PartyRoom, Error> { request(path: "rooms", method: "POST", body: try? JSONEncoder().encode(["name": name])) }
    func fetchRooms() -> AnyPublisher<[PartyRoom], Error> { request(path: "rooms") }
    func addSuggestion(roomID: String, track: Track) -> AnyPublisher<SuggestedTrack, Error> { request(path: "rooms/\(roomID)/suggestions", method: "POST", body: try? JSONEncoder().encode(["uri": track.uri, "title": track.name, "artist": track.artist])) }
    func fetchSuggestions(roomID: String) -> AnyPublisher<[SuggestedTrack], Error> { request(path: "rooms/\(roomID)/suggestions") }
    func vote(suggestionID: String, delta: Int) -> AnyPublisher<Void, Error> { request(path: "suggestions/\(suggestionID)/vote", method: "POST", body: try? JSONEncoder().encode(["delta": delta])) .map { (_: EmptyResponse) in () }.eraseToAnyPublisher() }
    func fetchTopSuggestion(roomID: String) -> AnyPublisher<SuggestedTrack, Error> { request(path: "rooms/\(roomID)/top") }
    func markPlayed(suggestionID: String) -> AnyPublisher<Void, Error> { request(path: "suggestions/\(suggestionID)/played", method: "POST") .map { (_: EmptyResponse) in () }.eraseToAnyPublisher() }
}

struct EmptyResponse: Decodable {}
