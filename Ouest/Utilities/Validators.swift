import Foundation

enum Validators {
    static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    static func isValidPassword(_ password: String) -> Bool {
        password.count >= 8
    }

    static func isValidHandle(_ handle: String) -> Bool {
        let pattern = #"^[a-zA-Z0-9_]{3,20}$"#
        return handle.range(of: pattern, options: .regularExpression) != nil
    }
}
