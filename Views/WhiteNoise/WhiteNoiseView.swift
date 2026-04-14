// WhiteNoiseView.swift
import SwiftUI

struct WhiteNoiseView: View {
    @StateObject private var svc = WhiteNoiseAPIService.shared
    @State private var selectedTab: WhiteNoiseTab = .online
    @State private var selectedCategory: SoundCategoryID = .rain
    @State private var volume: Float = 0.5
    @Environment(\.colorScheme) private var colorScheme

    enum WhiteNoiseTab { case online, local, favorites }

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color(hex: "#12121f") : .white).ignoresSafeArea()

                VStack(spacing: 0) {

                    // ── Now-Playing bar ────────────────────────────────
                    if let playing = svc.currentlyPlaying {
                        NowPlayingBar(
                            sound: playing,
                            volume: $volume,
                            isBuffering: svc.isBuffering,
                            onStop:  { svc.stopPlayback() },
                            onVolumeChange: { svc.setVolume($0) },
                            onFavorite: { svc.toggleFavorite(playing) },
                            isFavorite: svc.isFavorite(playing)
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // ── Tab selector ───────────────────────────────────
                    HStack(spacing: 0) {
                        TabButton(label: "Online", icon: "antenna.radiowaves.left.and.right",
                                  isSelected: selectedTab == .online) { selectedTab = .online }
                        TabButton(label: "Local",  icon: "iphone",
                                  isSelected: selectedTab == .local)  { selectedTab = .local }
                        TabButton(label: "Saved",  icon: "heart.fill",
                                  isSelected: selectedTab == .favorites) { selectedTab = .favorites }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    // ── Content ────────────────────────────────────────
                    switch selectedTab {
                    case .online:
                        OnlineSoundsTab(
                            svc: svc,
                            selectedCategory: $selectedCategory,
                            volume: $volume
                        )
                    case .local:
                        LocalSoundsTab(svc: svc, volume: $volume)
                    case .favorites:
                        FavoritesSoundsTab(svc: svc, volume: $volume)
                    }
                }
            }
            .navigationTitle("White Noise")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(colorScheme == .dark ? Color(hex: "#12121f") : .white, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .animation(.easeInOut(duration: 0.2), value: svc.currentlyPlaying?.id)
        }
    }
}

// MARK: - Online Sounds Tab
struct OnlineSoundsTab: View {
    @ObservedObject var svc: WhiteNoiseAPIService
    @Binding var selectedCategory: SoundCategoryID
    @Binding var volume: Float

    var body: some View {
        VStack(spacing: 0) {
            // Category horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AppConstants.freesoundCategories) { cat in
                        CategoryPill(
                            category: cat,
                            isSelected: selectedCategory == cat.id
                        ) {
                            selectedCategory = cat.id
                            Task { await svc.fetchCategory(cat.id) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            // Error banner
            if let error = svc.errorMessage {
                ErrorBannerView(message: error) {
                    Task { await svc.fetchCategory(selectedCategory) }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }

            // Sound list / grid
            if svc.isLoading {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView().tint(.orange).scaleEffect(1.3)
                    Text("Loading sounds...").font(.caption).foregroundColor(.gray)
                }
                Spacer()
            } else if svc.currentPage.sounds.isEmpty {
                EmptyOnlineView {
                    Task { await svc.fetchCategory(selectedCategory) }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Result count header
                        HStack {
                            Text("\(svc.currentPage.totalCount) sounds found")
                                .font(.caption).foregroundColor(.gray)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)

                        // Sound rows
                        ForEach(svc.currentPage.sounds) { sound in
                            SoundRowView(
                                sound: sound,
                                isPlaying: svc.currentlyPlaying?.id == sound.id,
                                isFavorite: svc.isFavorite(sound),
                                onPlay: {
                                    if svc.currentlyPlaying?.id == sound.id {
                                        svc.stopPlayback()
                                    } else {
                                        svc.play(sound: sound, volume: volume)
                                    }
                                },
                                onFavorite: { svc.toggleFavorite(sound) }
                            )
                            .onAppear {
                                Task { await svc.loadMoreIfNeeded(currentSound: sound) }
                            }
                        }

                        // Load more indicator
                        if svc.isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView().tint(.orange)
                                Text("Loading more...").font(.caption).foregroundColor(.gray)
                                Spacer()
                            }
                            .padding(16)
                        }

                        if svc.currentPage.isLastPage && !svc.currentPage.sounds.isEmpty {
                            Text("All sounds loaded ✓")
                                .font(.caption2).foregroundColor(.gray.opacity(0.4))
                                .padding(.vertical, 20)
                        }
                    }
                }
            }
        }
        .onAppear {
            if svc.currentPage.sounds.isEmpty {
                Task { await svc.fetchCategory(selectedCategory) }
            }
        }
    }
}

// MARK: - Local Sounds Tab
struct LocalSoundsTab: View {
    @ObservedObject var svc: WhiteNoiseAPIService
    @Binding var volume: Float

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                InfoBannerView(
                    message: "Add .mp3 files to your Xcode target to enable local playback.",
                    icon: "info.circle"
                )
                .padding(16)

                LazyVStack(spacing: 0) {
                    ForEach(AppConstants.localSounds) { sound in
                        SoundRowView(
                            sound: sound,
                            isPlaying: svc.currentlyPlaying?.id == sound.id,
                            isFavorite: svc.isFavorite(sound),
                            onPlay: {
                                if svc.currentlyPlaying?.id == sound.id {
                                    svc.stopPlayback()
                                } else {
                                    svc.play(sound: sound, volume: volume)
                                }
                            },
                            onFavorite: { svc.toggleFavorite(sound) }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Favorites Tab
struct FavoritesSoundsTab: View {
    @ObservedObject var svc: WhiteNoiseAPIService
    @Binding var volume: Float

    var body: some View {
        Group {
            if svc.favorites.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "heart.slash").font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("No saved sounds yet").font(.headline).foregroundColor(.gray)
                    Text("Tap ♥ on any sound to save it here")
                        .font(.caption).foregroundColor(.gray.opacity(0.6))
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(svc.favorites) { sound in
                            SoundRowView(
                                sound: sound,
                                isPlaying: svc.currentlyPlaying?.id == sound.id,
                                isFavorite: true,
                                onPlay: {
                                    if svc.currentlyPlaying?.id == sound.id {
                                        svc.stopPlayback()
                                    } else {
                                        svc.play(sound: sound, volume: volume)
                                    }
                                },
                                onFavorite: { svc.toggleFavorite(sound) }
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Sound Row View (list-style with detail)
struct SoundRowView: View {
    let sound: WhiteNoiseSound
    let isPlaying: Bool
    let isFavorite: Bool
    let onPlay: () -> Void
    let onFavorite: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            // Play / waveform button
            Button(action: onPlay) {
                ZStack {
                    Circle()
                        .fill(isPlaying
                            ? LinearGradient(colors: [.orange, Color(hex: "#e05c00")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color.primary.opacity(0.12), Color.primary.opacity(0.08)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 48, height: 48)
                        .shadow(color: isPlaying ? .orange.opacity(0.35) : .clear, radius: 8)
                    if isPlaying {
                        MiniWaveIcon()
                    } else {
                        Image(systemName: sound.icon)
                            .font(.body).foregroundColor(.gray)
                    }
                }
            }
            .buttonStyle(.plain)

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(sound.name)
                    .font(.subheadline)
                    .fontWeight(isPlaying ? .semibold : .regular)
                    .foregroundColor(isPlaying ? .primary : .primary.opacity(0.9))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if !sound.authorName.isEmpty {
                        Label(sound.authorName, systemImage: "person.fill")
                            .font(.caption2).foregroundColor(.gray)
                    }
                    if sound.durationSeconds > 0 {
                        Label(formatDuration(sound.durationSeconds), systemImage: "clock")
                            .font(.caption2).foregroundColor(.gray)
                    }
                    if sound.isLocal {
                        Text("LOCAL")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                    }
                }

                // Tags
                if !sound.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(sound.tags.prefix(4).enumerated()), id: \.offset) { _, tag in
                                Text(tag)
                                    .font(.system(size: 9))
                                    .foregroundColor(.gray.opacity(0.7))
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Color.primary.opacity(0.06))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }

            Spacer()

            // Favorite button
            Button(action: onFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.body)
                    .foregroundColor(isFavorite ? .red : .gray.opacity(0.5))
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isPlaying ? Color.orange.opacity(0.07) : Color.clear)
        .animation(.easeInOut(duration: 0.2), value: isPlaying)
        Divider().background(Color.primary.opacity(0.08)).padding(.leading, 78)
    }

    private func formatDuration(_ sec: Double) -> String {
        let m = Int(sec) / 60; let s = Int(sec) % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }
}

// MARK: - Mini Wave Icon (animated bars)
struct MiniWaveIcon: View {
    @State private var animate = false
    let heights: [Double] = [0.5, 0.9, 1.0, 0.7, 0.4]
    var body: some View {
        HStack(spacing: 2) {
            ForEach(heights.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white)
                    .frame(width: 3, height: animate ? 16 * heights[i] : 5 * heights[i])
                    .animation(
                        .easeInOut(duration: 0.45).repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.08),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

// MARK: - Now Playing Bar (enhanced)
struct NowPlayingBar: View {
    let sound: WhiteNoiseSound
    @Binding var volume: Float
    let isBuffering: Bool
    let onStop: () -> Void
    let onVolumeChange: (Float) -> Void
    let onFavorite: () -> Void
    let isFavorite: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                // Animated icon or buffering
                ZStack {
                    Circle().fill(Color.orange.opacity(0.2)).frame(width: 36, height: 36)
                    if isBuffering {
                        ProgressView().tint(.orange).scaleEffect(0.8)
                    } else {
                        MiniWaveIcon()
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("NOW PLAYING").font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.orange)
                    Text(sound.name).font(.caption).fontWeight(.semibold).foregroundColor(.primary)
                        .lineLimit(1)
                    if !sound.authorName.isEmpty {
                        Text("by \(sound.authorName)").font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                // Favorite
                Button(action: onFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(isFavorite ? .red : .gray)
                        .font(.body)
                }
                .buttonStyle(.plain)

                // Stop
                Button(action: onStop) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray.opacity(0.7)).font(.title3)
                }
                .buttonStyle(.plain)
            }

            // Volume slider
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill").foregroundColor(.gray).font(.caption)
                Slider(value: $volume, in: 0...1) { _ in onVolumeChange(volume) }
                    .tint(.orange)
                Image(systemName: "speaker.wave.3.fill").foregroundColor(.gray).font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(colorScheme == .dark ? Color(hex: "#1e1e30") : Color(hex: "#f3f4f8"))
        .overlay(Rectangle().frame(height: 1).foregroundColor(.orange.opacity(0.3)), alignment: .bottom)
    }
}

// MARK: - Category Pill
struct CategoryPill: View {
    let category: SoundCategory
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: category.icon)
                    .font(.caption)
                    .foregroundColor(isSelected ? Color(hex: category.color) : .gray)
                Text(category.label)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(isSelected
                ? Color(hex: category.color).opacity(0.2)
                : (colorScheme == .dark ? Color.primary.opacity(0.08) : Color.black.opacity(0.05)))
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? Color(hex: category.color) : Color.clear, lineWidth: 1.5))
        }
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let label: String; let icon: String; let isSelected: Bool; let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.subheadline).fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundColor(isSelected ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(isSelected ? Color.orange.opacity(0.18) : Color.clear)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1))
        }
    }
}

// MARK: - Error Banner
struct ErrorBannerView: View {
    let message: String; let onRetry: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            Text(message).font(.caption).foregroundColor(.primary.opacity(0.85)).lineLimit(2)
            Spacer()
            Button("Retry", action: onRetry).font(.caption).fontWeight(.semibold).foregroundColor(.orange)
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Info Banner
struct InfoBannerView: View {
    let message: String; let icon: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(.cyan)
            Text(message).font(.caption).foregroundColor(.gray)
        }
        .padding(10)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Empty Online State
struct EmptyOnlineView: View {
    let onRetry: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "waveform.slash").font(.system(size: 48)).foregroundColor(.gray.opacity(0.3))
            Text("No sounds yet").font(.headline).foregroundColor(.gray)
            Text("Select a category above to load sounds").font(.caption).foregroundColor(.gray.opacity(0.6))
            Button("Load Now", action: onRetry)
                .foregroundColor(.orange).fontWeight(.semibold)
                .padding(.horizontal, 24).padding(.vertical, 10)
                .background(Color.orange.opacity(0.15)).cornerRadius(10)
            Spacer()
        }
    }
}
