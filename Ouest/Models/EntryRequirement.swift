import Foundation
import SwiftUI

// MARK: - Travel Buddy API v2 Response Models

struct VisaCheckResponse: Codable, Sendable {
    let data: VisaCheckData
}

struct VisaCheckData: Codable, Sendable {
    let passport: PassportInfo
    let destination: DestinationInfo
    let mandatoryRegistration: MandatoryRegistration?
    let visaRules: VisaRules

    enum CodingKeys: String, CodingKey {
        case passport, destination
        case mandatoryRegistration = "mandatory_registration"
        case visaRules = "visa_rules"
    }
}

struct PassportInfo: Codable, Sendable {
    let code: String
    let name: String
}

struct DestinationInfo: Codable, Sendable {
    let code: String
    let name: String
    let continent: String?
    let capital: String?
    let currencyCode: String?
    let currency: String?
    let passportValidity: String?
    let phoneCode: String?
    let timezone: String?
    let embassyUrl: String?

    enum CodingKeys: String, CodingKey {
        case code, name, continent, capital, currency, timezone
        case currencyCode = "currency_code"
        case passportValidity = "passport_validity"
        case phoneCode = "phone_code"
        case embassyUrl = "embassy_url"
    }
}

struct MandatoryRegistration: Codable, Sendable {
    let name: String
    let color: String?
    let link: String?
}

struct VisaRules: Codable, Sendable {
    let primaryRule: VisaRule?
    let secondaryRule: VisaRule?

    enum CodingKeys: String, CodingKey {
        case primaryRule = "primary_rule"
        case secondaryRule = "secondary_rule"
    }
}

struct VisaRule: Codable, Sendable {
    let name: String
    let duration: String?
    let color: String?
    let link: String?
}

// MARK: - Visa Color Mapping

enum VisaColor: String, Sendable {
    case green
    case blue
    case yellow
    case red
    case gray

    init(apiColor: String?) {
        switch apiColor?.lowercased() {
        case "green": self = .green
        case "blue": self = .blue
        case "yellow": self = .yellow
        case "red": self = .red
        default: self = .gray
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .green: .green
        case .blue: .blue
        case .yellow: .orange
        case .red: .red
        case .gray: .gray
        }
    }

    var icon: String {
        switch self {
        case .green: "checkmark.seal.fill"
        case .blue: "doc.text.fill"
        case .yellow: "exclamationmark.triangle.fill"
        case .red: "xmark.seal.fill"
        case .gray: "questionmark.circle.fill"
        }
    }
}

// MARK: - Display Wrapper

struct EntryRequirementResult: Identifiable, Sendable {
    let id = UUID()
    let destinationCode: String
    let destinationName: String
    let response: VisaCheckData?
    let error: String?

    var isSuccess: Bool { response != nil }
}
