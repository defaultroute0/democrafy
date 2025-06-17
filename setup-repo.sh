#!/usr/bin/env bash

# setup-repo.sh
# Script to scaffold the OutloudDJ project locally with full iOS client & Node backend
# Place this file in an empty folder, then run:
#   chmod +x setup-repo.sh
#   ./setup-repo.sh
# It will create directories, write all source files, and initialize a git repo.

set -e

echo "=== OutloudDJ Local Repo Setup ==="

# 1) Create project directories
echo "Creating directories..."
mkdir -p OutloudDJ-iOS/{Models,Services,ViewModels,Views,Resources}
mkdir -p OutloudDJ-Backend

echo "Directories created."

# 2) Write iOS client files
# AppEntry.swift
cat > OutloudDJ-iOS/AppEntry.swift << 'EOF'
import SwiftUI

@main
struct OutloudDJApp: App {
    @StateObject private var authService = SpotifyAuthService()
    @StateObject private var apiService: SpotifyAPIService
    @StateObject private var backendService = PartyBackendService(baseURL: URL(string: "http://localhost:3000")!)

    init() {
        let auth = SpotifyAuthService()
        _authService = StateObject(wrappedValue: auth)
        _apiService = StateObject(wrappedValue: SpotifyAPIService(authService: auth))
    }

    var body: some Scene {
        WindowGroup {
            NavigationView {
                LobbyView()
            }
            .environmentObject(authService)
            .environmentObject(apiService)
            .environmentObject(backendService)
        }
    }
}
EOF

echo "Written: OutloudDJ-iOS/AppEntry.swift"

# Models
cat > OutloudDJ-iOS/Models/PartyRoom.swift << 'EOF'
import Foundation

struct PartyRoom: Identifiable, Codable {
    let id: String
    let name: String
    let hostUserID: String
}
EOF

echo "Written: Models/PartyRoom.swift"

cat > OutloudDJ-iOS/Models/SuggestedTrack.swift << 'EOF'
import Foundation

struct SuggestedTrack: Identifiable, Codable {
    let id: String
    let uri: String
    let title: String
    let artist: String
    let votes: Int
    let timestamp: Date
    var sortKey: VoteSortKey { VoteSortKey(votes: votes, timestamp: timestamp) }
}

struct VoteSortKey: Comparable {
    let votes: Int
    let timestamp: Date
    static func < (lhs: VoteSortKey, rhs: VoteSortKey) -> Bool {
        if lhs.votes != rhs.votes { return lhs.votes > rhs.votes }
        return lhs.timestamp < rhs.timestamp
    }
}
EOF

echo "Written: Models/SuggestedTrack.swift"

cat > OutloudDJ-iOS/Models/SpotifyDevice.swift << 'EOF'
import Foundation

struct SpotifyDevice: Identifiable, Codable {
    let id: String
    let name: String
    let type: String
    let isActive: Bool
}
EOF

echo "Written: Models/SpotifyDevice.swift"

cat > OutloudDJ-iOS/Models/Track.swift << 'EOF'
import Foundation

struct Track: Identifiable, Codable {
    let id: String
    let uri: String
    let name: String
    let artist: String
    let albumArtURL: URL
}
EOF

echo "Written: Models/Track.swift"

cat > OutloudDJ-iOS/Models/PlaybackState.swift << 'EOF'
import Foundation

struct PlaybackState: Codable {
    let isPlaying: Bool
    let progressMs: Int
    let item: Track?
}
EOF

echo "Written: Models/PlaybackState.swift"

# Services
cat > OutloudDJ-iOS/Services/SpotifyAuthService.swift << 'EOF'
import Foundation
import Combine
import CryptoKit
import AuthenticationServices

class SpotifyAuthService: NSObject, ObservableObject {
    @Published var accessToken: String?; @Published var refreshToken: String?; @Published var isAuthenticated = false
    private var codeVerifier = ""; private var authSession: ASWebAuthenticationSession?
    let clientID = "YOUR_SPOTIFY_CLIENT_ID"; let redirectURI = URL(string: "outlouddj://callback")!
    let scopes = ["user-read-playback-state","user-modify-playback-state","playlist-modify-private","user-read-currently-playing"]

    func authorize() {
        codeVerifier = Self.randomString(length: 128)
        let challenge = codeVerifier.sha256().base64URLEncodedString()
        var c = URLComponents(string: "https://accounts.spotify.com/authorize")!
        c.queryItems = [
            .init(name: "client_id", value: clientID), .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: redirectURI.absoluteString), .init(name: "scope", value: scopes.joined(separator: " ")),
            .init(name: "code_challenge_method", value: "S256"), .init(name: "code_challenge", value: challenge)
        ]
        authSession = ASWebAuthenticationSession(url: c.url!, callbackURLScheme: redirectURI.scheme) { callback, _ in
            guard let url = callback,
                  let code = URLComponents(string: url.absoluteString)?.queryItems?.first(where: { $0.name == "code" })?.value
            else { return }
            self.exchange(code: code)
        }
        authSession?.presentationContextProvider = self
        authSession?.start()
    }

    private func exchange(code: String) {
        var r = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        r.httpMethod = "POST"
        let b = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "code_verifier", value: codeVerifier)
        ]
        r.httpBody = URLComponents(queryItems: b).percentEncodedQuery?.data(using: .utf8)
        r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        URLSession.shared.dataTask(with: r) { data, _, _ in
            guard let d = data,
                  let t = try? JSONDecoder().decode(TokenResponse.self, from: d)
            else { return }
            DispatchQueue.main.async {
                self.accessToken = t.access_token
                self.refreshToken = t.refresh_token
                self.isAuthenticated = true
            }
        }.resume()
    }

    func refresh() {
        guard let tok = refreshToken else { return }
        var r = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        r.httpMethod = "POST"
        let b = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: tok),
            URLQueryItem(name: "client_id", value: clientID)
        ]
        r.httpBody = URLComponents(queryItems: b).percentEncodedQuery?.data(using: .utf8)
        r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        URLSession.shared.dataTask(with: r) { data, _, _ in
            guard let d = data,
                  let t = try? JSONDecoder().decode(TokenResponse.self, from: d)
            else { return }
            DispatchQueue.main.async { self.accessToken = t.access_token }
        }.resume()
    }

    static func randomString(length: Int) -> String {
        let cs = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).map { _ in cs.randomElement()! })
    }
}

extension SpotifyAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

struct TokenResponse: Decodable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
    let scope: String
}
EOF

echo "Written: Services/SpotifyAuthService.swift"

cat > OutloudDJ-iOS/Services/SpotifyAPIService.swift << 'EOF'
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
EOF

echo "Written: Services/SpotifyAPIService.swift"

cat > OutloudDJ-iOS/Services/PartyBackendService.swift << 'EOF'
import Foundation
import Combine

class PartyBackendService: ObservableObject {
    let baseURL: URL
    init(baseURL: URL) { self.baseURL = baseURL }

    private func request<T: Decodable>(path: String, method: String = "GET", body: Data? = nil) -> AnyPublisher<T, Error> {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        if let b = body { req.httpBody = b; req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        return URLSession.shared.dataTaskPublisher(for: req)
            .tryMap { res -> Data in
                guard let code = (res.response as? HTTPURLResponse)?.statusCode, 200..<300 ~= code else { throw URLError(.badServerResponse) }
                return res.data
            }
            .decode(type: T.self, decoder: JSONDecoder())
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
EOF

echo "Written: Services/PartyBackendService.swift"

# ViewModels
cat > OutloudDJ-iOS/ViewModels/LobbyViewModel.swift << 'EOF'
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
EOF

echo "Written: ViewModels/LobbyViewModel.swift"

cat > OutloudDJ-iOS/ViewModels/SearchViewModel.swift << 'EOF'
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
EOF

echo "Written: ViewModels/SearchViewModel.swift"

cat > OutloudDJ-iOS/ViewModels/QueueViewModel.swift << 'EOF'
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
EOF

echo "Written: ViewModels/QueueViewModel.swift"

cat > OutloudDJ-iOS/ViewModels/PlayerViewModel.swift << 'EOF'
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
EOF

echo "Written: ViewModels/PlayerViewModel.swift"

# Views
cat > OutloudDJ-iOS/Views/LobbyView.swift << 'EOF'
import SwiftUI

struct LobbyView: View {
    @EnvironmentObject var backend: PartyBackendService
    @StateObject private var vm: LobbyViewModel

    init() {
        _vm = StateObject(wrappedValue: LobbyViewModel(backendService: PartyBackendService(baseURL: URL(string: "http://localhost:3000")!)))
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
EOF

echo "Written: Views/LobbyView.swift"

cat > OutloudDJ-iOS/Views/SearchView.swift << 'EOF'
import SwiftUI

struct SearchView: View {
    @StateObject var vm: SearchViewModel
    let room: PartyRoom

    var body: some View {
        VStack {
            TextField("Search Spotify…", text: $vm.query)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            List(vm.results) { track in
                HStack {
                    VStack(alignment: .leading) {
                        Text(track.name)
                        Text(track.artist).font(.subheadline).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: { vm.suggest(track: track, in: room) }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
        }
        .navigationTitle("Search")
    }
}
EOF

echo "Written: Views/SearchView.swift"

cat > OutloudDJ-iOS/Views/QueueView.swift << 'EOF'
import SwiftUI

struct QueueView: View {
    let room: PartyRoom
    @StateObject private var vm: QueueViewModel

    init(room: PartyRoom) {
        self.room = room
        _vm = StateObject(wrappedValue: QueueViewModel(backendService: PartyBackendService(baseURL: URL(string: "http://localhost:3000")!)))
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
        .toolbar { NavigationLink("Search", destination: SearchView(vm: SearchViewModel(apiService: SpotifyAPIService(authService: SpotifyAuthService()), backendService: PartyBackendService(baseURL: URL(string: "http://localhost:3000")!)), room: room)) }
        .onAppear { vm.fetchSuggestions(roomID: room.id) }
    }
}
EOF

echo "Written: Views/QueueView.swift"

cat > OutloudDJ-iOS/Views/PlayerView.swift << 'EOF'
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
EOF

echo "Written: Views/PlayerView.swift"

cat > OutloudDJ-iOS/Views/MockupViews.swift << 'EOF'
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
EOF

echo "Written: Views/MockupViews.swift"

# 3) Write backend files
cat > OutloudDJ-Backend/package.json << 'EOF'
{
  "name": "outlouddj-backend",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": { "start": "node server.js" },
  "dependencies": { "cors": "^2.8.5", "express": "^4.18.2", "uuid": "^9.0.0" }
}
EOF

echo "Written: OutloudDJ-Backend/package.json"

cat > OutloudDJ-Backend/server.js << 'EOF'
const express = require('express');
const { v4: uuid } = require('uuid');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const rooms = {};
const suggestions = {};

app.post('/rooms', (req, res) => {
  const id = uuid();
  rooms[id] = { id, name: req.body.name, hostID: req.body.hostID || null };
  suggestions[id] = [];
  res.json(rooms[id]);
});

app.get('/rooms', (req, res) => res.json(Object.values(rooms)));

app.post('/rooms/:roomID/suggestions', (req, res) => {
  const { roomID } = req.params;
  const id = uuid();
  const item = { id, uri: req.body.uri, title: req.body.title, artist: req.body.artist, votes: 0, timestamp: new Date(), played: false };
  suggestions[roomID].push(item);
  res.json(item);
});

app.get('/rooms/:roomID/suggestions', (req, res) => {
  res.json(suggestions[req.params.roomID] || []);
});

app.post('/suggestions/:id/vote', (req, res) => {
  const { id } = req.params;
  let found;
  Object.values(suggestions).forEach(arr => arr.forEach(item => { if(item.id === id) found = item; }));
  if (found) { found.votes += Number(req.body.delta); return res.json({}); }
  res.status(404).json({ error: 'Not found' });
});

app.get('/rooms/:roomID/top', (req, res) => {
  const list = (suggestions[req.params.roomID] || []).filter(x => !x.played);
  const top = list.sort((a,b) => b.votes - a.votes || new Date(a.timestamp) - new Date(b.timestamp))[0] || null;
  res.json(top);
});

app.post('/suggestions/:id/played', (req, res) => {
  const { id } = req.params;
  Object.values(suggestions).forEach(arr => arr.forEach(item => { if(item.id === id) item.played = true; }));
  res.json({});
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Backend running on port ${PORT}`));
EOF

echo "Written: OutloudDJ-Backend/server.js"

# 4) Initialize Git repository
if [ ! -d .git ]; then
  git init
  git add .
  git commit -m "Initial commit: scaffold iOS client & Node backend"
  echo "Git repository initialized at $(pwd)"
else
  echo "Git repository already initialized."
fi

echo "=== Setup Complete ==="
