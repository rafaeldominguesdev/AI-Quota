import AppKit
import SwiftUI
import AIQuotaCore

/// Mapeia o `QuotaState` do núcleo para cores de sistema, usadas tanto no NSStatusItem
/// (AppKit) quanto no painel (SwiftUI), garantindo que ambos fiquem visualmente consistentes
/// e respeitem modo claro/escuro automaticamente.
enum StatusColor {
    static func nsColor(for state: QuotaState) -> NSColor {
        switch state {
        case .safe: return .systemGreen
        case .warning: return .systemOrange
        case .danger: return .systemRed
        }
    }

    static func color(for state: QuotaState) -> Color {
        Color(nsColor: nsColor(for: state))
    }

    static let neutralNSColor = NSColor.secondaryLabelColor
    static let neutralColor = Color(nsColor: .secondaryLabelColor)
}
