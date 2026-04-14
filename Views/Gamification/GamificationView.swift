//
//  GamificationView.swift
//  FocusFlow
//
//  Created by mustaahh on 14/4/26.
//


import SwiftUI

struct GamificationView: View {
    @ObservedObject var vm: GamificationViewModel
    @State private var selectedCategory: AchievementCategory? = nil
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color(hex: "#0d1324"), Color(hex: "#12121f"), Color(hex: "#1a1a2e")]
                        : [Color.white, Color(hex: "#f7f8fb"), Color(hex: "#eef2f7")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // ── Level & XP Card ──────────────────────────
                        LevelProgressCard(progress: vm.progress)
                            .padding(.horizontal, 16)

                        // ── Stats Row ────────────────────────────────
                        StatsRowView(progress: vm.progress)
                            .padding(.horizontal, 16)

                        // ── Achievements ─────────────────────────────
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Achievements")
                                    .font(.headline).fontWeight(.bold).foregroundColor(.primary)
                                Spacer()
                                Text("\(vm.unlockedCount)/\(vm.achievements.count)")
                                    .font(.caption).foregroundColor(.orange)
                            }
                            .padding(.horizontal, 16)

                            // Category filter pills
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    CategoryFilterPill(
                                        label: "All",
                                        icon: "square.grid.2x2",
                                        isSelected: selectedCategory == nil,
                                        colorHex: "#888888"
                                    ) { selectedCategory = nil }

                                    ForEach(AchievementCategory.allCases, id: \.self) { cat in
                                        CategoryFilterPill(
                                            label: cat.label,
                                            icon: cat.icon,
                                            isSelected: selectedCategory == cat,
                                            colorHex: cat.colorHex
                                        ) { selectedCategory = selectedCategory == cat ? nil : cat }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }

                            // Achievement list
                            let filtered = selectedCategory == nil
                                ? vm.achievements
                                : vm.achievements.filter { $0.category == selectedCategory }

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(filtered) { achievement in
                                    AchievementCard(achievement: achievement)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 32)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(colorScheme == .dark ? Color(hex: "#12121f") : .white, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .onAppear { vm.loadProgress() }
            // Level up banner
            .overlay(alignment: .top) {
                if vm.showLevelUpBanner {
                    LevelUpBanner(title: vm.levelUpTitle) {
                        vm.showLevelUpBanner = false
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
                }
            }
            .animation(.spring(response: 0.4), value: vm.showLevelUpBanner)
        }
    }
}

// MARK: - Level Progress Card

struct LevelProgressCard: View {
    let progress: UserProgress

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {

                // XP Ring
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.12), lineWidth: 10)
                        .frame(width: 90, height: 90)

                    Circle()
                        .trim(from: 0, to: progress.levelProgress)
                        .stroke(
                            LinearGradient(colors: [.orange, Color(hex: "#FF6B35")],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.8), value: progress.levelProgress)

                    VStack(spacing: 2) {
                        Text(progress.level.emoji)
                            .font(.title2)
                        Text("Lv \(progress.level.level)")
                            .font(.caption2).fontWeight(.bold).foregroundColor(.orange)
                    }
                }

                // Level info
                VStack(alignment: .leading, spacing: 6) {
                    Text(progress.level.title)
                        .font(.title3).fontWeight(.bold).foregroundColor(.primary)

                    Text("\(progress.totalXP) XP total")
                        .font(.subheadline).foregroundColor(.gray)

                    // XP bar
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.primary.opacity(0.12))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(colors: [.orange, Color(hex: "#FF6B35")],
                                                          startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * CGFloat(progress.levelProgress), height: 6)
                                    .animation(.easeInOut(duration: 0.8), value: progress.levelProgress)
                            }
                        }
                        .frame(height: 6)

                        if let next = progress.nextLevel {
                            Text("\(progress.xpInCurrentLevel) / \(progress.xpNeededForNextLevel) XP → Lv \(next.level)")
                                .font(.caption2).foregroundColor(.gray)
                        } else {
                            Text("Max level reached! 🏆")
                                .font(.caption2).foregroundColor(.orange)
                        }
                    }
                }

                Spacer()
            }

            // Coins row
            HStack(spacing: 16) {
                CoinBadge(value: progress.coins, label: "Coins", icon: "bitcoinsign.circle.fill", color: .yellow)
                CoinBadge(value: progress.currentStreak, label: "Streak", icon: "flame.fill", color: .orange)
                CoinBadge(value: progress.longestStreak, label: "Best", icon: "trophy.fill", color: Color(hex: "#FFD700"))
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.primary.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.orange.opacity(0.25), lineWidth: 1))
        )
    }
}

struct CoinBadge: View {
    let value: Int; let label: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption).foregroundColor(color)
                Text("\(value)").font(.subheadline).fontWeight(.bold).foregroundColor(.primary)
            }
            Text(label).font(.caption2).foregroundColor(.gray)
        }
    }
}

// MARK: - Stats Row

struct StatsRowView: View {
    let progress: UserProgress

    var body: some View {
        HStack(spacing: 12) {
            MiniStatCard(value: "\(progress.totalPomodoros)", label: "Pomodoros", icon: "timer", color: .orange)
            MiniStatCard(value: formatMins(progress.totalFocusMinutes), label: "Focus", icon: "clock.fill", color: .blue)
            MiniStatCard(value: "\(progress.totalTasksCompleted)", label: "Tasks", icon: "checkmark.circle.fill", color: .green)
        }
    }

    func formatMins(_ mins: Int) -> String {
        if mins < 60 { return "\(mins)m" }
        return "\(mins / 60)h\(mins % 60 > 0 ? "\(mins % 60)m" : "")"
    }
}

struct MiniStatCard: View {
    let value: String; let label: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundColor(color)
            Text(value).font(.headline).fontWeight(.bold).foregroundColor(.primary)
            Text(label).font(.caption2).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.primary.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1))
        )
    }
}

// MARK: - Achievement Card

struct AchievementCard: View {
    let achievement: Achievement

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(achievement.isUnlocked
                              ? Color(hex: achievement.category.colorHex).opacity(0.25)
                              : Color.primary.opacity(0.08))
                        .frame(width: 40, height: 40)
                    Image(systemName: achievement.icon)
                        .font(.headline)
                        .foregroundColor(achievement.isUnlocked
                                         ? Color(hex: achievement.category.colorHex)
                                         : .gray.opacity(0.5))
                }
                Spacer()
                if achievement.isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption).foregroundColor(.green)
                } else {
                    Text("+\(achievement.xpReward) XP")
                        .font(.caption2).foregroundColor(.gray)
                }
            }

            Text(achievement.title)
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(achievement.isUnlocked ? .white : .gray)
                .lineLimit(1)

            Text(achievement.description)
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.8))
                .lineLimit(2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(achievement.isUnlocked
                      ? Color(hex: achievement.category.colorHex).opacity(0.08)
                      : Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(achievement.isUnlocked
                                ? Color(hex: achievement.category.colorHex).opacity(0.35)
                                : Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
        .opacity(achievement.isUnlocked ? 1.0 : 0.7)
    }
}

// MARK: - Category Filter Pill

struct CategoryFilterPill: View {
    let label: String; let icon: String; let isSelected: Bool; let colorHex: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption2)
                Text(label).font(.caption).fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .gray)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(isSelected
                         ? Color(hex: colorHex).opacity(0.3)
                         : Color.primary.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? Color(hex: colorHex) : Color.clear, lineWidth: 1.5))
            .cornerRadius(20)
        }
    }
}

// MARK: - Level Up Banner

struct LevelUpBanner: View {
    let title: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.title2).foregroundColor(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Level Up!").font(.caption).foregroundColor(.orange).fontWeight(.bold)
                Text(title).font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.caption).foregroundColor(.gray)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "#1a1a2e"))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.orange.opacity(0.5), lineWidth: 1.5))
        )
        .shadow(color: .orange.opacity(0.2), radius: 12)
        .padding(.horizontal, 16)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { onDismiss() }
        }
    }
}

// MARK: - Achievement Unlocked Toast (used in TimerView / elsewhere)

struct AchievementToast: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: achievement.category.colorHex).opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: achievement.icon)
                    .foregroundColor(Color(hex: achievement.category.colorHex))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Achievement Unlocked! +\(achievement.xpReward) XP")
                    .font(.caption).foregroundColor(.orange)
                Text(achievement.title)
                    .font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "#1a1a2e"))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(hex: achievement.category.colorHex).opacity(0.5), lineWidth: 1.5))
        )
        .shadow(color: Color(hex: achievement.category.colorHex).opacity(0.25), radius: 12)
        .padding(.horizontal, 16)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { onDismiss() }
        }
    }
}
