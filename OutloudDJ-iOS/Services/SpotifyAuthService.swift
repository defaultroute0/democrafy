import Foundation
import Combine
import CryptoKit
import AuthenticationServices
import os.log

private let logger = Logger(subsystem: "com.outlouddj.app", category: "SpotifyAuthService")

class SpotifyAuthService: NSObject, ObservableObject {
    @Published var accessToken: String?
    @Published var refreshToken: String?
    @Published var isAuthenticated = false
    @Published var error: Error?
    
    private var codeVerifier = ""
    private var authSession: ASWebAuthenticationSession?
    private var cancellables = Set<AnyCancellable>()
    
    private let clientID: String
    private let redirectURI: URL
    private let scopes: [String]
    
    init() {
        self.clientID = Config.spotifyClientID
        self.redirectURI = Config.redirectURI
        self.scopes = Config.scopes
        super.init()
    }

    func authorize() {
        guard !isAuthenticated else {
            logger.debug("Already authenticated")
            return
        }
        
        codeVerifier = Self.randomString(length: 128)
        let challenge = codeVerifier.sha256().base64URLEncodedString()
        
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge)
        ]
        
        guard let authURL = components.url else {
            logger.error("Failed to create authorization URL")
            DispatchQueue.main.async { self.error = NSError(domain: "Authorization", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create authorization URL"]) }
            return
        }
        
        authSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: redirectURI.scheme) { [weak self] callback, error in
            guard let self = self else { return }
            
            if let error = error {
                logger.error("Authorization failed: \(error.localizedDescription)")
                DispatchQueue.main.async { self.error = error }
                return
            }
            
            guard let url = callback,
                  let code = URLComponents(string: url.absoluteString)?.queryItems?.first(where: { $0.name == "code" })?.value
            else {
                logger.error("Invalid authorization callback")
                DispatchQueue.main.async { self.error = NSError(domain: "Authorization", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid authorization response"]) }
                return
            }
            
            self.exchange(code: code)
        }
        
        authSession?.presentationContextProvider = self
        authSession?.start()
    }

    private func exchange(code: String) {
        guard let tokenURL = URL(string: "https://accounts.spotify.com/api/token") else {
            logger.error("Failed to create token URL")
            DispatchQueue.main.async { self.error = NSError(domain: "TokenExchange", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create token URL"]) }
            return
        }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        
        let bodyItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "code_verifier", value: codeVerifier)
        ]
        
        request.httpBody = URLComponents(queryItems: bodyItems).percentEncodedQuery?.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { response -> Data in
                guard let httpResponse = response.response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return response.data
            }
            .decode(type: TokenResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    logger.error("Token exchange failed: \(error.localizedDescription)")
                    self.error = error
                }
            } receiveValue: { [weak self] token in
                self?.accessToken = token.access_token
                self?.refreshToken = token.refresh_token
                self?.isAuthenticated = true
                self?.error = nil
            }
            .store(in: &cancellables)
    }
    }

    func refresh() {
        guard let refreshToken = self.refreshToken else {
            logger.error("No refresh token available")
            DispatchQueue.main.async { self.error = NSError(domain: "Refresh", code: -1, userInfo: [NSLocalizedDescriptionKey: "No refresh token available"]) }
            return
        }
        
        guard let tokenURL = URL(string: "https://accounts.spotify.com/api/token") else {
            logger.error("Failed to create token URL")
            DispatchQueue.main.async { self.error = NSError(domain: "Refresh", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create token URL"]) }
            return
        }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        
        let bodyItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "client_id", value: clientID)
        ]
        
        request.httpBody = URLComponents(queryItems: bodyItems).percentEncodedQuery?.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { response -> Data in
                guard let httpResponse = response.response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return response.data
            }
            .decode(type: TokenResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    logger.error("Token refresh failed: \(error.localizedDescription)")
                    self.error = error
                }
            } receiveValue: { [weak self] token in
                self?.accessToken = token.access_token
                self?.error = nil
            }
            .store(in: &cancellables)
    }
    }

    static func randomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
    
    deinit {
        logger.debug("Deinitializing SpotifyAuthService")
        authSession?.cancel()
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
