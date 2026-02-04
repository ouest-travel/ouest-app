import Foundation

/// Currency formatting utilities
enum CurrencyFormatter {

    /// Currency symbols mapping
    private static let symbols: [String: String] = [
        "USD": "$",
        "EUR": "€",
        "GBP": "£",
        "CAD": "CA$",
        "AUD": "A$",
        "JPY": "¥",
        "CNY": "¥",
        "KRW": "₩",
        "INR": "₹",
        "BRL": "R$",
        "MXN": "MX$",
        "CHF": "CHF",
        "SEK": "kr",
        "NOK": "kr",
        "DKK": "kr",
        "NZD": "NZ$",
        "SGD": "S$",
        "HKD": "HK$",
        "THB": "฿",
        "PHP": "₱",
        "MYR": "RM",
        "IDR": "Rp",
        "VND": "₫",
        "ZAR": "R",
        "AED": "د.إ",
        "SAR": "﷼",
        "TRY": "₺",
        "PLN": "zł",
        "CZK": "Kč",
        "HUF": "Ft",
        "ILS": "₪",
        "CLP": "CLP$",
        "COP": "COP$",
        "ARS": "ARS$",
        "PEN": "S/"
    ]

    /// Currencies that don't use decimal places
    private static let noDecimalCurrencies = ["JPY", "KRW", "VND", "IDR", "CLP", "HUF"]

    /// Get currency symbol for a currency code
    static func symbol(for currency: String) -> String {
        symbols[currency.uppercased()] ?? currency
    }

    /// Format an amount with the appropriate currency symbol
    static func format(amount: Decimal, currency: String) -> String {
        let currencyCode = currency.uppercased()
        let symbol = self.symbol(for: currencyCode)

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        if noDecimalCurrencies.contains(currencyCode) {
            formatter.maximumFractionDigits = 0
        } else {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
        }

        let formattedNumber = formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
        return "\(symbol)\(formattedNumber)"
    }

    /// Format an amount with currency code (for display in lists)
    static func formatWithCode(amount: Decimal, currency: String) -> String {
        let formatted = format(amount: amount, currency: currency)
        return "\(formatted) \(currency.uppercased())"
    }

    /// Parse a string amount to Decimal
    static func parse(_ string: String) -> Decimal? {
        let cleanedString = string
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)

        return Decimal(string: cleanedString)
    }
}

// MARK: - Supported Currencies

extension CurrencyFormatter {

    struct Currency: Identifiable, Hashable {
        let code: String
        let name: String
        let symbol: String

        var id: String { code }
    }

    static let supportedCurrencies: [Currency] = [
        Currency(code: "USD", name: "US Dollar", symbol: "$"),
        Currency(code: "EUR", name: "Euro", symbol: "€"),
        Currency(code: "GBP", name: "British Pound", symbol: "£"),
        Currency(code: "CAD", name: "Canadian Dollar", symbol: "CA$"),
        Currency(code: "AUD", name: "Australian Dollar", symbol: "A$"),
        Currency(code: "JPY", name: "Japanese Yen", symbol: "¥"),
        Currency(code: "CNY", name: "Chinese Yuan", symbol: "¥"),
        Currency(code: "KRW", name: "South Korean Won", symbol: "₩"),
        Currency(code: "INR", name: "Indian Rupee", symbol: "₹"),
        Currency(code: "BRL", name: "Brazilian Real", symbol: "R$"),
        Currency(code: "MXN", name: "Mexican Peso", symbol: "MX$"),
        Currency(code: "CHF", name: "Swiss Franc", symbol: "CHF"),
        Currency(code: "SGD", name: "Singapore Dollar", symbol: "S$"),
        Currency(code: "HKD", name: "Hong Kong Dollar", symbol: "HK$"),
        Currency(code: "THB", name: "Thai Baht", symbol: "฿"),
        Currency(code: "NZD", name: "New Zealand Dollar", symbol: "NZ$")
    ]
}
