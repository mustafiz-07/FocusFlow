//
//  BlockerViewModel.swift
//  FocusFlow
//
//  Created by mustaahh on 14/4/26.
//


import Foundation
import Combine

@MainActor
final class BlockerViewModel: ObservableObject {

    // MARK: - Published

    @Published var settings: BlockerSettings = BlockerSettings.load()

    /// True while a focus session is running AND the blocker is enabled
    @Published var isShieldActive: Bool = false

    /// Strict mode exit countdown (counts down from strictExitDelaySeconds → 0)
    @Published var exitCountdown: Int = 10

    /// Drives the strict-mode overlay visibility inside TimerView
    @Published var showStrictExitOverlay: Bool = false

    /// Set true when user force-exits during strict mode (TimerVM reads this)
    @Published var penaltyTriggered: Bool = false

    // MARK: - Private

    private var countdownTimer: AnyCancellable? = nil

    // MARK: - Shield lifecycle (called by TimerViewModel)

    func startShield() {
        guard settings.isBlockerEnabled else { return }
        isShieldActive = true
    }

    func stopShield() {
        isShieldActive = false
        showStrictExitOverlay = false
        stopCountdown()
    }

    // MARK: - Stop request routing (called by TimerView stop button)

    /// Returns true if stop was allowed immediately.
    /// Returns false if strict mode is blocking — overlay will be shown instead.
    @discardableResult
    func requestStop() -> Bool {
        guard isShieldActive,
              settings.isBlockerEnabled,
              settings.isStrictModeEnabled else {
            return true  // allow stop immediately
        }
        // Strict mode active — show overlay + start countdown
        exitCountdown = settings.strictExitDelaySeconds
        showStrictExitOverlay = true
        startCountdown()
        return false     // stop blocked — overlay shown
    }

    /// User clicked "Stay Focused" — dismiss the overlay
    func cancelExit() {
        showStrictExitOverlay = false
        stopCountdown()
    }

    /// User clicked "Exit Anyway" after countdown — trigger penalty
    func confirmForceExit() {
        penaltyTriggered = true
        showStrictExitOverlay = false
        stopCountdown()
        // penaltyTriggered is read once by TimerView then cleared
    }

    func clearPenalty() { penaltyTriggered = false }

    // MARK: - Countdown

    private func startCountdown() {
        countdownTimer?.cancel()
        countdownTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.exitCountdown > 0 {
                    self.exitCountdown -= 1
                } else {
                    self.stopCountdown()
                }
            }
    }

    private func stopCountdown() {
        countdownTimer?.cancel()
        countdownTimer = nil
    }

    // MARK: - Settings mutations

    func toggleBlocker() {
        settings.isBlockerEnabled.toggle()
        if !settings.isBlockerEnabled { stopShield() }
        save()
    }

    func toggleStrictMode() {
        settings.isStrictModeEnabled.toggle()
        save()
    }

    func save() {
        settings.save()
    }

    // MARK: - Computed helpers

    var statusLabel: String {
        guard settings.isBlockerEnabled else { return "Off" }
        return "On"
    }
}
