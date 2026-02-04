import SwiftUI

/// Manages app theme (dark/light mode)
class ThemeManager: ObservableObject {
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false

    var colorScheme: ColorScheme? {
        isDarkMode ? .dark : .light
    }

    var isDark: Bool {
        isDarkMode
    }

    func toggleTheme() {
        isDarkMode.toggle()
    }

    func setDarkMode(_ enabled: Bool) {
        isDarkMode = enabled
    }

    // MARK: - Adaptive Colors

    var background: Color {
        isDarkMode ? OuestTheme.Colors.Dark.background : OuestTheme.Colors.background
    }

    var cardBackground: Color {
        isDarkMode ? OuestTheme.Colors.Dark.cardBackground : OuestTheme.Colors.cardBackground
    }

    var text: Color {
        isDarkMode ? OuestTheme.Colors.Dark.text : OuestTheme.Colors.text
    }

    var textSecondary: Color {
        isDarkMode ? OuestTheme.Colors.Dark.textSecondary : OuestTheme.Colors.textSecondary
    }

    var inputBackground: Color {
        isDarkMode ? OuestTheme.Colors.Dark.inputBackground : OuestTheme.Colors.inputBackground
    }

    var border: Color {
        isDarkMode ? OuestTheme.Colors.Dark.border : OuestTheme.Colors.border
    }
}
