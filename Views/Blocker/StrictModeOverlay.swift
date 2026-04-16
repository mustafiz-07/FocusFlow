//
//  StrictModeOverlay.swift
//  FocusFlow
//
//  Created by mustaahh on 14/4/26.
//


import SwiftUI

// MARK: - Strict Mode Overlay

/// Full-screen overlay shown when user tries to stop during strict mode.
/// Shows motivational message + countdown before allowing force-exit.
struct StrictModeOverlay: View {
    @ObservedObject var blockerVM: BlockerViewModel

    // Shame messages — rotate randomly on each show
    private let shameMessages = [
        "You said this was important.",
        "Champions don't quit halfway.",
        "Your future self is watching.",
        "Just a few more minutes. You've got this.",
        "The distraction will still be there after. Focus wins.",
        "Every expert was once a beginner who didn't quit.",
        "Discomfort is temporary. Results are permanent.",
        "You started this for a reason. Remember it.",
    ]

    @State private var shameMessage = "You said this was important."

    var canExit: Bool { blockerVM.exitCountdown == 0 }

    var body: some View {
        ZStack {
            // Frosted dark background
            Color.black.opacity(0.82)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 28) {

                // ── Shield icon with pulse ────────────────────────
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 100, height: 100)
                        .scaleEffect(canExit ? 1.0 : 1.08)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: canExit)

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(canExit ? .orange : .red)
                        .symbolRenderingMode(.hierarchical)
                }

                // ── Heading ───────────────────────────────────────
                VStack(spacing: 8) {
                    Text(canExit ? "Still want to exit?" : "Strict Mode Active")
                        .font(.title2).fontWeight(.bold).foregroundColor(.white)

                    if blockerVM.settings.showShameMessage {
                        Text(shameMessage)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }

                // ── Countdown ring ────────────────────────────────
                if !canExit {
                    CountdownRing(
                        current: blockerVM.exitCountdown,
                        total: blockerVM.settings.strictExitDelaySeconds
                    )
                }

                // ── XP penalty warning ────────────────────────────
                HStack(spacing: 8) {
                    Image(systemName: "bolt.badge.xmark.fill")
                        .foregroundColor(.red).font(.subheadline)
                    Text("Early exit will cost you \(blockerVM.settings.exitPenaltyXP) XP")
                        .font(.subheadline).foregroundColor(.red.opacity(0.9))
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)

                // ── Buttons ───────────────────────────────────────
                VStack(spacing: 12) {
                    // Stay Focused — primary action
                    Button(action: blockerVM.cancelExit) {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill").font(.subheadline)
                            Text("Stay Focused 💪")
                                .font(.headline).fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [.orange, Color(hex: "#e05c00")],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(14)
                        .shadow(color: .orange.opacity(0.4), radius: 8)
                    }

                    // Force exit — only available after countdown
                    Button(action: blockerVM.confirmForceExit) {
                        Text(canExit ? "Exit Anyway (−\(blockerVM.settings.exitPenaltyXP) XP)" : "Exit unlocks in \(blockerVM.exitCountdown)s…")
                            .font(.subheadline)
                            .foregroundColor(canExit ? .red.opacity(0.85) : .gray.opacity(0.45))
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.white.opacity(canExit ? 0.06 : 0.03))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(canExit ? Color.red.opacity(0.35) : Color.clear, lineWidth: 1))
                            .cornerRadius(12)
                    }
                    .disabled(!canExit)
                    .animation(.easeInOut, value: canExit)
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 40)
        }
        .onAppear {
            shameMessage = shameMessages.randomElement() ?? shameMessages[0]
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }
}

// MARK: - Countdown Ring

private struct CountdownRing: View {
    let current: Int
    let total: Int

    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 6)
                .frame(width: 80, height: 80)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: [.red, .orange],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)

            Text("\(current)")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Focus Shield Banner (shown inside TimerView during active session)

struct FocusShieldBanner: View {
    @ObservedObject var blockerVM: BlockerViewModel
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Collapsed pill
            Button { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "shield.fill")
                        .font(.caption).foregroundColor(.orange)

                    Text("Focus Shield Active")
                        .font(.caption).fontWeight(.semibold).foregroundColor(.white)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2).foregroundColor(.gray)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.orange.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1))
                .cornerRadius(12)
            }

            // Expanded detail
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Distraction protection is active for this session.")
                        .font(.caption2).foregroundColor(.gray)

                    if blockerVM.settings.isStrictModeEnabled {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield.fill")
                                .font(.caption2).foregroundColor(.red)
                            Text("Strict mode: \(blockerVM.settings.strictExitDelaySeconds)s delay + \(blockerVM.settings.exitPenaltyXP) XP penalty on exit")
                                .font(.caption2).foregroundColor(.red.opacity(0.8))
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.orange.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1))
                .cornerRadius(12)
            }
        }
    }
}
