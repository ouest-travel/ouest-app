import Foundation

extension Date {
    var formatted_MMMd: String {
        self.formatted(.dateTime.month(.abbreviated).day())
    }

    var formatted_MMMdyyyy: String {
        self.formatted(.dateTime.month(.abbreviated).day().year())
    }

    var isInPast: Bool {
        self < Date.now
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
}
