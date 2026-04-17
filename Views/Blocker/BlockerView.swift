//
//  BlockerView.swift
//  FocusFlow
//
//  Created by mustaahh on 14/4/26.
//


import SwiftUI

struct BlockerView: View {
    @ObservedObject var blockerVM: BlockerViewModel
    @State private var expandedSection: ExpandedSection? = .settings
    @Environment(\.colorScheme) private var colorScheme

    enum ExpandedSection { case settings }
    private var isDark: Bool { colorScheme == .dark }
    private var navBg: Color { isDark ? Color(hex: "#12121f") : .white }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: isDark
                        ? [Color(hex: "#0d1324"), Color(hex: "#12121f"), Color(hex: "#1a1a2e")]
                        : [Color.white, Color(hex: "#f7f8fb"), Color(hex: "#eef2f7")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        // ── Master toggle card ────────────────────
                        MasterToggleCard(blockerVM: blockerVM)
                            .padding(.horizontal, 16)

                        // ── Strict mode card ──────────────────────
                        StrictModeCard(blockerVM: blockerVM)
                            .padding(.horizontal, 16)

                        // ── Penalty settings ──────────────────────
                        BlockerSection(
                            title: "Penalty Settings",
                            subtitle: "\(blockerVM.settings.exitPenaltyXP) XP on early exit",
                            icon: "bolt.badge.xmark.fill",
                            isExpanded: expandedSection == .settings,
                            onToggle: { expandedSection = expandedSection == .settings ? nil : .settings }
                        ) {
                            VStack(spacing: 12) {
                                PenaltyStepperRow(
                                    label: "Exit Delay",
                                    icon: "clock.badge.exclamationmark.fill",
                                    value: $blockerVM.settings.strictExitDelaySeconds,
                                    range: 3...30,
                                    step: 1,
                                    unit: "sec",
                                    color: .orange
                                ) { blockerVM.save() }

                                PenaltyStepperRow(
                                    label: "XP Penalty",
                                    icon: "bolt.badge.xmark.fill",
                                    value: $blockerVM.settings.exitPenaltyXP,
                                    range: 10...200,
                                    step: 10,
                                    unit: "XP",
                                    color: .red
                                ) { blockerVM.save() }

                                PenaltyToggleRow(
                                    label: "Show Shame Message",
                                    icon: "exclamationmark.bubble.fill",
                                    isOn: $blockerVM.settings.showShameMessage,
                                    color: .yellow
                                ) { blockerVM.save() }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                        }
                        .padding(.horizontal, 16)

                        Spacer(minLength: 30)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Focus Blocker")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(navBg, for: .navigationBar)
            .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
        }
    }
}

// MARK: - Master Toggle Card

private struct MasterToggleCard: View {
    @ObservedObject var blockerVM: BlockerViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        let primaryText: Color = isDark ? .white : .black
        let secondaryText: Color = isDark ? .gray : .secondary
        HStack(spacing: 16) {
            // Shield icon with pulse when active
            ZStack {
                Circle()
                    .fill(blockerVM.settings.isBlockerEnabled
                          ? Color.orange.opacity(0.2) : Color.white.opacity(0.06))
                    .frame(width: 56, height: 56)

                if blockerVM.isShieldActive {
                    Circle()
                        .stroke(Color.orange.opacity(0.4), lineWidth: 2)
                        .frame(width: 56, height: 56)
                        .scaleEffect(blockerVM.isShieldActive ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(), value: blockerVM.isShieldActive)
                }

                Image(systemName: blockerVM.isShieldActive ? "shield.fill" : "shield")
                    .font(.title2)
                    .foregroundColor(blockerVM.settings.isBlockerEnabled ? .orange : .gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(blockerVM.isShieldActive ? "Shield Active" : "Focus Blocker")
                    .font(.headline).fontWeight(.bold).foregroundColor(primaryText)
                Text(blockerVM.isShieldActive
                     ? "Blocking \(blockerVM.statusLabel) during session"
                     : blockerVM.settings.isBlockerEnabled
                         ? "Ready · \(blockerVM.statusLabel)"
                         : "Enable to block distractions")
                    .font(.caption).foregroundColor(secondaryText)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get:  { blockerVM.settings.isBlockerEnabled },
                set:  { _ in blockerVM.toggleBlocker() }
            ))
            .tint(.orange)
            .labelsHidden()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(blockerVM.settings.isBlockerEnabled
                      ? Color.orange.opacity(0.08) : Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 18)
                    .stroke(blockerVM.settings.isBlockerEnabled
                            ? Color.orange.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1.5))
        )
    }
}

// MARK: - Strict Mode Card

private struct StrictModeCard: View {
    @ObservedObject var blockerVM: BlockerViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        let primaryText: Color = isDark ? .white : .black
        let secondaryText: Color = isDark ? .gray : .secondary
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(.headline)
                    .foregroundColor(blockerVM.settings.isStrictModeEnabled ? .red : .gray)
                    .padding(8)
                    .background((blockerVM.settings.isStrictModeEnabled ? Color.red : Color.white).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Strict Mode")
                        .font(.subheadline).fontWeight(.semibold).foregroundColor(primaryText)
                    Text("Delays exit by \(blockerVM.settings.strictExitDelaySeconds)s · \(blockerVM.settings.exitPenaltyXP) XP penalty")
                        .font(.caption).foregroundColor(secondaryText)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get:  { blockerVM.settings.isStrictModeEnabled },
                    set:  { _ in blockerVM.toggleStrictMode() }
                ))
                .tint(.red)
                .labelsHidden()
                .disabled(!blockerVM.settings.isBlockerEnabled)
            }

            if blockerVM.settings.isStrictModeEnabled {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill").font(.caption).foregroundColor(.red.opacity(0.8))
                    Text("In strict mode, stopping the timer early shows a \(blockerVM.settings.strictExitDelaySeconds)-second countdown and deducts \(blockerVM.settings.exitPenaltyXP) XP.")
                        .font(.caption).foregroundColor(secondaryText)
                }
                .padding(10)
                .background(Color.red.opacity(0.08))
                .cornerRadius(10)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(blockerVM.settings.isStrictModeEnabled
                            ? Color.red.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1))
        )
        .opacity(blockerVM.settings.isBlockerEnabled ? 1.0 : 0.45)
    }
}

// MARK: - Collapsible Section

private struct BlockerSection<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: () -> Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        let primaryText: Color = isDark ? .white : .black
        let secondaryText: Color = isDark ? .gray : .secondary
        VStack(spacing: 0) {
            // Header
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline).fontWeight(.semibold).foregroundColor(primaryText)
                        Text(subtitle)
                            .font(.caption).foregroundColor(secondaryText)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundColor(.gray)
                }
                .padding(14)
            }

            if isExpanded {
                Divider().background(Color.white.opacity(0.08))
                content()
                    .padding(.bottom, 6)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}

// MARK: - Penalty stepper / toggle rows (local to BlockerView)

private struct PenaltyStepperRow: View {
    let label: String; let icon: String
    @Binding var value: Int
    let range: ClosedRange<Int>; let step: Int; let unit: String; let color: Color
    let onChange: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(color).frame(width: 28)
            Text(label).font(.subheadline).foregroundColor(colorScheme == .dark ? .white : .black)
            Spacer()
            Text("\(value) \(unit)").font(.subheadline).foregroundColor(.gray).frame(minWidth: 60, alignment: .trailing)
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
                .onChange(of: value) { _ in onChange() }
        }
        .padding(.vertical, 6)
    }
}

private struct PenaltyToggleRow: View {
    let label: String; let icon: String
    @Binding var isOn: Bool
    let color: Color; let onChange: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(color).frame(width: 28)
            Text(label).font(.subheadline).foregroundColor(colorScheme == .dark ? .white : .black)
            Spacer()
            Toggle("", isOn: $isOn)
                .tint(color).labelsHidden()
                .onChange(of: isOn) { _ in onChange() }
        }
        .padding(.vertical, 6)
    }
}
