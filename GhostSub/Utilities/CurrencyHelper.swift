import Foundation

// MARK: - CurrencyHelper
// Single source of truth for currency formatting across the entire app.
// Prevents hardcoded "£" symbols appearing on USD/EUR subscriptions.

enum CurrencyHelper {

    /// Returns the display symbol for a given ISO currency code.
    static func symbol(for currency: String) -> String {
        switch currency.uppercased() {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "CAD": return "CA$"
        case "AUD": return "A$"
        case "JPY": return "¥"
        default:    return "£"
        }
    }

    /// Formats a cost value with the correct currency symbol.
    static func format(_ amount: Double, currency: String) -> String {
        let sym = symbol(for: currency)
        return "\(sym)\(String(format: "%.2f", amount))"
    }
}
