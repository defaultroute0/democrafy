import Foundation
import Combine

class SpotifyAPIService: ObservableObject {
    private let auth: SpotifyAuthService
    init(authService: SpotifyAuthService) { auth = authService }

    private func request(path: String, method: String = "GET", query: [URLQueryItem]? = nil, body: Data? = nil) -> AnyPublisher<Data, Error> {
        Deferred { Future { promise in
            guard let token = auth.accessToken else { return }
            var comps = URLComponents(string: "https://api.spotify.com/v1" + path)!
            comps.queryItems = query
            var req = URLRequest(url: comps.url!)
            req.httpMethod = method
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let b = body { req.httpBody = b; req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
            URLSession.shared.dataTask(with: req) { data, resp, err in
                if let err = err { promise(.failure(err)); return }
                guard let code = (resp as? HTTPURLResponse)?.statusCode, 200..<300 ~= code, let d = data else {
                    promise(.failure(URLError(.badServerResponse)))
                    return
                }
                promise(.success(d))
            }.resume()
        }}.eraseToAnyPublisher()
    }

    func searchTracks(query: String) -> AnyPublisher<[Track], Error> {
        let qs = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "type", value: "track"), URLQueryItem(name: "limit", value: "20")]
        return request(path: "/search", query: qs)
            .decode(type: SearchResponse.self, decoder: JSONDecoder())
            .map { $0.tracks.items.map { $0.toTrack() } }
            .eraseToAnyPublisher()
    }

    func fetchDevices() -> AnyPublisher<[SpotifyDevice], Error> {
        return request(path: "/me/player/devices")
            .decode(type: DeviceList.self, decoder: JSONDecoder())
            .map { $0.devices }
            .eraseToAnyPublisher()
    }

    func transferPlayback(to deviceID: String) -> AnyPublisher<Void, Error> {
        let b = try? JSONEncoder().encode(["device_ids": [deviceID], "play": true])
        return request(path: "/me/player", method: "PUT", body: b)
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    func enqueueTrack(uri: String) -> AnyPublisher<Void, Error> {
        let qs = [URLQueryItem(name: "uri", value: uri)]
        return request(path: "/me/player/queue", method: "POST", query: qs)
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    func skipToNext() -> AnyPublisher<Void, Error> {
        return request(path: "/me/player/next", method: "POST")
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    func fetchPlaybackState() -> AnyPublisher<PlaybackState, Error> {
        return request(path: "/me/player")
            .decode(type: PlaybackState.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}

// Supporting models
struct SearchResponse: Decodable {
    struct TrackItem: Decodable { let uri: String; let name: String; let artists: [Artist]; let album: Album }
    struct Artist: Decodable { let name: String }
    struct Album: Decodable { let images: [Image] }
    struct Image: Decodable { let url: String; let height: Int; let width: Int }
    struct Tracks: Decodable { let items: [TrackItem] }
    let tracks: Tracks
}

struct DeviceList: Decodable {
    let devices: [SpotifyDevice]
}

extension SearchResponse.TrackItem {
    func toTrack() -> Track {
        let imgURL = URL(string: album.images.first?.url ?? "")!
        return Track(id: uri, uri: uri, name: name, artist: artists.map { $0.name }.joined(separator: ", "), albumArtURL: imgURL)
    }
}
