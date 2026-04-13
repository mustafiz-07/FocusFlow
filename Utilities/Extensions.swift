// Extensions.swift
import Foundation
import SwiftUI

// MARK: - Date Extensions
extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
    var startOfWeek: Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self))!
    }
    var startOfMonth: Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: self))!
    }

    func isSameDay(as date: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: date)
    }

    var shortTimeString: String {
        let f = DateFormatter(); f.timeStyle = .short
        return f.string(from: self)
    }
    var shortDateString: String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
        return f.string(from: self)
    }
}

// MARK: - Int (seconds) → display string
extension Int {
    var timerString: String {
        let m = self / 60; let s = self % 60
        return String(format: "%02d:%02d", m, s)
    }
    var minuteLabel: String { "\(self) min" }
}

// MARK: - Color from hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        let int = UInt64(hex, radix: 16) ?? 0
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    init(designColor name: String) {
        switch name.lowercased() {
        case "gray":
            self = .gray
        case "red":
            self = .red
        case "orange":
            self = .orange
        case "blue":
            self = .blue
        case "green":
            self = .green
        case "purple":
            self = .purple
        case "cyan":
            self = .cyan
        case "yellow":
            self = .yellow
        case "white":
            self = .white
        case "black":
            self = .black
        default:
            if name.hasPrefix("#") {
                self.init(hex: name)
            } else {
                self = .clear
            }
        }
    }
}

// MARK: - View Modifiers
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color("CardBackground"))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardModifier()) }
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
