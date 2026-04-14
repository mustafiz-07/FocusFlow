//
//  GamificationViewModel.swift
//  FocusFlow
//
//  Created by mustaahh on 14/4/26.
//


import Foundation
import Combine

@MainActor
final class GamificationViewModel: ObservableObject {

    // MARK: - Published

    @Published var progress: UserProgress = UserProgress()
    @Published var achievements: [Achievement] = Achievement.catalog
    @Published var newlyUnlocked: [Achievement] = []          // shown as toast
    @Published var isLoading: Bool = false
    @Published var showLevelUpBanner: Bool = false
    @Published var levelUpTitle: String = ""

    // MARK: - Private

    private var uid: String? { AuthService.shared.uid }
    private var previousLevel: Int = 1

    // MARK: - Load

    func loadProgress() {
        guard let uid else { return }
        isLoading = true
        Task {
            do {
                let p = try await FirebaseService.shared.fetchUserProgress(uid: uid)
                self.progress = p
                previousLevel = p.level.level
                syncAchievementStates()
            } catch {
                // Start with empty progress on first launch
                self.progress = UserProgress()
            }
            isLoading = false
        }
    }

    // MARK: - Award XP for a completed Pomodoro session

    func sessionCompleted(durationMinutes: Int, sessionType: SessionType, task: FTask?) {
        guard sessionType == .focus, durationMinutes > 0 else { return }

        let xpEarned = UserProgress.xp(forFocusMinutes: durationMinutes)
        let streakBonus = UserProgress.xp(forStreakDay: progress.currentStreak)

        progress.totalXP             += xpEarned + streakBonus
        progress.totalPomodoros      += 1
        progress.totalFocusMinutes   += durationMinutes
        progress.coins               += max(1, durationMinutes / 5)

        updateStreak()
        checkAchievements()
        checkLevelUp()
        persist()
    }

    // MARK: - Award XP for completing a task

    func taskCompleted(priority: TaskPriority) {
        progress.totalXP           += UserProgress.xp(forTaskCompleted: priority)
        progress.totalTasksCompleted += 1
        checkAchievements()
        checkLevelUp()
        persist()
    }

    // MARK: - Award XP for study room actions

    func joinedRoom() {
        progress.totalXP         += UserProgress.xpForJoiningRoom
        progress.totalRoomsJoined += 1
        checkAchievements()
        checkLevelUp()
        persist()
    }

    func hostedRoom() {
        progress.totalXP          += UserProgress.xpForHostingRoom
        progress.totalRoomsHosted += 1
        checkAchievements()
        checkLevelUp()
        persist()
    }

    // MARK: - Streak Management

    private func updateStreak() {
        let today = Calendar.current.startOfDay(for: Date())

        if let last = progress.lastFocusDate {
            let lastDay = Calendar.current.startOfDay(for: last)
            let diff = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if diff == 0 {
                // Already focused today — no change
            } else if diff == 1 {
                // Consecutive day
                progress.currentStreak += 1
                progress.longestStreak = max(progress.longestStreak, progress.currentStreak)
            } else {
                // Streak broken
                progress.currentStreak = 1
            }
        } else {
            // First ever session
            progress.currentStreak = 1
            progress.longestStreak = 1
        }
        progress.lastFocusDate = Date()
    }

    // MARK: - Achievement Checking

    private func checkAchievements() {
        var unlocked: [Achievement] = []
        for i in achievements.indices {
            if !achievements[i].isUnlocked && achievements[i].isMet(by: progress) {
                achievements[i].isUnlocked  = true
                achievements[i].unlockedAt  = Date()
                progress.totalXP           += achievements[i].xpReward
                progress.unlockedAchievementIds.append(achievements[i].id)
                unlocked.append(achievements[i])
            }
        }
        if !unlocked.isEmpty {
            newlyUnlocked = unlocked
        }
    }

    private func syncAchievementStates() {
        for i in achievements.indices {
            if progress.unlockedAchievementIds.contains(achievements[i].id) {
                achievements[i].isUnlocked = true
            }
        }
    }

    // MARK: - Level-up detection

    private func checkLevelUp() {
        let currentLevel = progress.level.level
        if currentLevel > previousLevel {
            levelUpTitle  = "\(progress.level.emoji) Level \(currentLevel): \(progress.level.title)!"
            showLevelUpBanner = true
            previousLevel = currentLevel
        }
    }

    // MARK: - Persist

    private func persist() {
        guard let uid else { return }
        Task {
            try? await FirebaseService.shared.saveUserProgress(progress, uid: uid)
        }
    }

    // MARK: - Convenience computed

    var unlockedCount: Int { achievements.filter { $0.isUnlocked }.count }
    var achievementsByCategory: [(AchievementCategory, [Achievement])] {
        AchievementCategory.allCases.compactMap { cat in
            let list = achievements.filter { $0.category == cat }
            return list.isEmpty ? nil : (cat, list)
        }
    }

    func clearNewlyUnlocked() { newlyUnlocked = [] }
}
