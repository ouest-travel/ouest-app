import Foundation

enum AppConstants {
    static let appName = "Ouest"
    static let maxImageSizeMB: Double = 5.0
    static let maxImageSizeBytes: Int = Int(maxImageSizeMB * 1_000_000)
    static let paginationLimit = 20
    static let shortCodeLength = 8
}
