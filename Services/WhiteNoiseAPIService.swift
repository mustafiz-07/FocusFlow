// WhiteNoiseAPIService.swift
// Freesound API – Project: FocusFlow
// Client ID : vNVR4yscmS2JMiQxZB9X
// API Key   : 2z0mCF98pC0pLi74TmEuJUjO4YNfkWEgw9CoiNVG
import Foundation
import AVFoundation
import Combine

// MARK: - Freesound API Response Models

struct FreesoundSearchResponse: Codable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [FreesoundResult]
}

struct FreesoundResult: Codable, Identifiable {
    let id: Int
    let name: String
    let previews: FreesoundPreviews
    let duration: Double
    let username: String
    let tags: [String]
    let description: String?
    let avgRating: Double?
    let numRatings: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, previews, duration, username, tags, description
        case avgRating  = "avg_rating"
        case numRatings = "num_ratings"
    }
}

struct FreesoundPreviews: Codable {
    let previewHqMp3: String
    let previewLqMp3: String

    enum CodingKeys: String, CodingKey {
        case previewHqMp3 = "preview-hq-mp3"
        case previewLqMp3 = "preview-lq-mp3"
    }
}

struct FreesoundTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String
    let scope: String

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case tokenType    = "token_type"
        case expiresIn    = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

// MARK: - Pagination State
struct SoundPage {
    var sounds: [WhiteNoiseSound] = []
    var totalCount: Int = 0
    var currentPage: Int = 1
    var nextURL: String? = nil
    var isLastPage: Bool { nextURL == nil }
}

// MARK: - WhiteNoiseAPIService

@MainActor
final class WhiteNoiseAPIService: ObservableObject {
    static let shared = WhiteNoiseAPIService()

    @Published var currentPage: SoundPage = SoundPage()
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String? = nil
    @Published var favorites: [WhiteNoiseSound] = []
    @Published var isOAuthAuthenticated = false
    @Published var currentlyPlaying: WhiteNoiseSound? = nil
    @Published var isBuffering = false

    private(set) var activeCategory: SoundCategoryID = .rain

    private var streamPlayer: AVPlayer?
    private var localPlayer: AVAudioPlayer?
    private var playerObserver: Any?

    private let kAccessToken  = "freesound_access_token"
    private let kRefreshToken = "freesound_refresh_token"
    private let kFavoritesKey = "focusflow_favorite_sounds"
    private let session = URLSession.shared

    var accessToken: String?  { UserDefaults.standard.string(forKey: kAccessToken) }
    var refreshToken: String? { UserDefaults.standard.string(forKey: kRefreshToken) }

    private init() {
        loadFavorites()
        isOAuthAuthenticated = accessToken != nil
    }

    // MARK: - URL builder
    private func searchURL(query: String, page: Int = 1, pageSize: Int = 15) -> URL? {
        var comps = URLComponents(string: "\(AppConstants.freesoundBaseURL)/search/text/")
        comps?.queryItems = [
            URLQueryItem(name: "query",     value: query),
            URLQueryItem(name: "fields",    value: "id,name,previews,duration,username,tags,description,avg_rating,num_ratings"),
            URLQueryItem(name: "filter",    value: "duration:[10 TO 360] type:mp3"),
            URLQueryItem(name: "sort",      value: "rating_desc"),
            URLQueryItem(name: "page_size", value: "\(pageSize)"),
            URLQueryItem(name: "page",      value: "\(page)"),
            URLQueryItem(name: "token",     value: AppConstants.freesoundAPIKey),
        ]
        return comps?.url
    }

    // MARK: - Fetch first page
    func fetchCategory(_ categoryId: SoundCategoryID) async {
        guard let cat = AppConstants.freesoundCategories.first(where: { $0.id == categoryId }) else { return }
        activeCategory = categoryId
        currentPage = SoundPage()
        isLoading = true
        errorMessage = nil
        await fetchPage(query: cat.queries[0], page: 1, category: cat, append: false)
        isLoading = false
    }

    // MARK: - Load more (infinite scroll)
    func loadMoreIfNeeded(currentSound: WhiteNoiseSound) async {
        let sounds = currentPage.sounds
        guard !currentPage.isLastPage, !isLoadingMore,
              let idx = sounds.firstIndex(of: currentSound),
              idx >= sounds.count - 4 else { return }
        isLoadingMore = true
        let nextPage = currentPage.currentPage + 1
        guard let cat = AppConstants.freesoundCategories.first(where: { $0.id == activeCategory }) else {
            isLoadingMore = false; return
        }
        let qIdx = (nextPage - 1) % cat.queries.count
        await fetchPage(query: cat.queries[qIdx], page: nextPage, category: cat, append: true)
        isLoadingMore = false
    }

    // MARK: - Core network call
    private func fetchPage(query: String, page: Int, category: SoundCategory, append: Bool) async {
        guard let url = searchURL(query: query, page: page) else {
            errorMessage = "Invalid search URL"; return
        }
        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                switch http.statusCode {
                case 401: errorMessage = "Invalid API key – check Constants.swift"
                case 429: errorMessage = "Rate limited – please wait a moment"
                default:  errorMessage = "Freesound HTTP \(http.statusCode)"
                }
                return
            }
            let decoded = try JSONDecoder().decode(FreesoundSearchResponse.self, from: data)
            let newSounds: [WhiteNoiseSound] = decoded.results.map { r in
                WhiteNoiseSound(
                    id: "fs_\(r.id)",
                    name: cleanName(r.name),
                    icon: category.icon,
                    isLocal: false,
                    category: category.id,
                    streamURL: r.previews.previewHqMp3,
                    freesoundId: r.id,
                    durationSeconds: r.duration,
                    authorName: r.username,
                    isFavorite: favorites.contains(where: { $0.freesoundId == r.id }),
                    tags: Array(r.tags.prefix(5))
                )
            }
            if append {
                currentPage.sounds.append(contentsOf: newSounds)
            } else {
                currentPage.sounds = newSounds
                currentPage.currentPage = 1
            }
            currentPage.totalCount  = decoded.count
            currentPage.nextURL     = decoded.next
            currentPage.currentPage = page
        } catch let urlError as URLError {
            errorMessage = urlError.code == .notConnectedToInternet
                ? "No internet connection" : "Network error: \(urlError.localizedDescription)"
        } catch {
            errorMessage = "Parse error: \(error.localizedDescription)"
        }
    }

    // Sanitise Freesound filenames
    private func cleanName(_ raw: String) -> String {
        var s = raw
        for ext in [".mp3",".wav",".ogg",".flac",".aiff"] {
            s = s.replacingOccurrences(of: ext, with: "", options: .caseInsensitive)
        }
        s = s.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        s = s.trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? raw : s.prefix(1).uppercased() + s.dropFirst()
    }

    // MARK: - Playback

    func play(sound: WhiteNoiseSound, volume: Float = 0.5) {
        stopPlayback()
        currentlyPlaying = sound
        isBuffering = true
        if sound.isLocal {
            playLocal(named: sound.id, volume: volume)
        } else if let urlStr = sound.streamURL, let url = URL(string: urlStr) {
            playStream(url: url, volume: volume)
        }
    }

    func setVolume(_ volume: Float) {
        streamPlayer?.volume = volume
        localPlayer?.volume  = volume
    }

    func stopPlayback() {
        if let obs = playerObserver { NotificationCenter.default.removeObserver(obs); playerObserver = nil }
        streamPlayer?.pause(); streamPlayer = nil
        localPlayer?.stop();   localPlayer = nil
        currentlyPlaying = nil
        isBuffering = false
    }

    private func playStream(url: URL, volume: Float) {
        setupAudioSession()
        let item = AVPlayerItem(url: url)
        streamPlayer = AVPlayer(playerItem: item)
        streamPlayer?.volume = volume
        streamPlayer?.play()
        isBuffering = false
        playerObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
                self?.streamPlayer?.seek(to: .zero)
                self?.streamPlayer?.play()
        }
    }

    private func playLocal(named: String, volume: Float) {
        setupAudioSession()
        for ext in ["mp3","wav","m4a","aiff"] {
            if let url = Bundle.main.url(forResource: named, withExtension: ext) {
                do {
                    localPlayer = try AVAudioPlayer(contentsOf: url)
                    localPlayer?.numberOfLoops = -1
                    localPlayer?.volume = volume
                    localPlayer?.prepareToPlay()
                    localPlayer?.play()
                    isBuffering = false
                    return
                } catch { continue }
            }
        }
        errorMessage = "'\(named).mp3' not found – add audio files to your Xcode target"
        currentlyPlaying = nil
        isBuffering = false
    }

    private func setupAudioSession() {
        try? AVAudioSession.sharedInstance()
            .setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Favorites

    func toggleFavorite(_ sound: WhiteNoiseSound) {
        if let idx = favorites.firstIndex(where: { $0.id == sound.id }) {
            favorites.remove(at: idx)
        } else {
            favorites.append(sound)
        }
        saveFavorites()
        if let idx = currentPage.sounds.firstIndex(where: { $0.id == sound.id }) {
            currentPage.sounds[idx].isFavorite.toggle()
        }
    }

    func isFavorite(_ sound: WhiteNoiseSound) -> Bool {
        favorites.contains(where: { $0.id == sound.id })
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: kFavoritesKey)
        }
    }

    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: kFavoritesKey),
           let saved = try? JSONDecoder().decode([WhiteNoiseSound].self, from: data) {
            favorites = saved
        }
    }

    // MARK: - OAuth2 helpers (ready when needed for full downloads)

    func buildOAuthURL() -> URL? {
        var c = URLComponents(string: AppConstants.freesoundOAuthURL)
        c?.queryItems = [
            URLQueryItem(name: "client_id",    value: AppConstants.freesoundClientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri",  value: AppConstants.freesoundCallbackURL),
        ]
        return c?.url
    }

    func exchangeCodeForToken(_ code: String) async throws {
        guard let url = URL(string: AppConstants.freesoundTokenURL) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "client_id=\(AppConstants.freesoundClientID)"
            .appending("&client_secret=\(AppConstants.freesoundAPIKey)")
            .appending("&grant_type=authorization_code")
            .appending("&code=\(code)")
            .appending("&redirect_uri=\(AppConstants.freesoundCallbackURL)")
            .data(using: .utf8)
        let (data, _) = try await session.data(for: req)
        let token = try JSONDecoder().decode(FreesoundTokenResponse.self, from: data)
        UserDefaults.standard.set(token.accessToken,  forKey: kAccessToken)
        UserDefaults.standard.set(token.refreshToken, forKey: kRefreshToken)
        isOAuthAuthenticated = true
    }

    func signOutFreesound() {
        UserDefaults.standard.removeObject(forKey: kAccessToken)
        UserDefaults.standard.removeObject(forKey: kRefreshToken)
        isOAuthAuthenticated = false
    }
}
