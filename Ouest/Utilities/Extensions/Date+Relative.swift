import Foundation

extension Date {
    /// Relative time text: "Just now", "5m", "2h", "3d", "2w", "Mar 15"
    var relativeText: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        guard interval > 0 else { return "Just now" }

        let seconds = Int(interval)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        let weeks = days / 7

        if seconds < 60 { return "Just now" }
        if minutes < 60 { return "\(minutes)m" }
        if hours < 24 { return "\(hours)h" }
        if days < 7 { return "\(days)d" }
        if weeks < 4 { return "\(weeks)w" }

        // Older than ~4 weeks: show date
        let formatter = DateFormatter()
        formatter.dateFormat = Calendar.current.isDate(self, equalTo: now, toGranularity: .year)
            ? "MMM d"
            : "MMM d, yyyy"
        return formatter.string(from: self)
    }
}
