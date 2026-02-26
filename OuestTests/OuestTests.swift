import Testing
@testable import Ouest

@Suite("Validators")
struct ValidatorTests {
    @Test("Valid email addresses")
    func validEmails() {
        #expect(Validators.isValidEmail("user@example.com"))
        #expect(Validators.isValidEmail("test.user@domain.co"))
    }

    @Test("Invalid email addresses")
    func invalidEmails() {
        #expect(!Validators.isValidEmail(""))
        #expect(!Validators.isValidEmail("notanemail"))
        #expect(!Validators.isValidEmail("@domain.com"))
    }

    @Test("Valid passwords")
    func validPasswords() {
        #expect(Validators.isValidPassword("password123"))
        #expect(Validators.isValidPassword("12345678"))
    }

    @Test("Invalid passwords")
    func invalidPasswords() {
        #expect(!Validators.isValidPassword(""))
        #expect(!Validators.isValidPassword("short"))
    }

    @Test("Valid handles")
    func validHandles() {
        #expect(Validators.isValidHandle("timmy"))
        #expect(Validators.isValidHandle("user_123"))
    }

    @Test("Invalid handles")
    func invalidHandles() {
        #expect(!Validators.isValidHandle("ab"))
        #expect(!Validators.isValidHandle("has spaces"))
        #expect(!Validators.isValidHandle("special!chars"))
    }
}
