import Foundation

public struct PIIMatch {
    public let type: PIIType
    public let value: String
    public let range: Range<String.Index>

    public init(type: PIIType, value: String, range: Range<String.Index>) {
        self.type = type
        self.value = value
        self.range = range
    }
}

public enum PIIType: String, CaseIterable {
    case creditCard = "credit_card"
    case ssn = "ssn"
    case email = "email"
    case phone = "phone"
    case apiKey = "api_key"
    case secretString = "secret_string"
}

public struct PIIPatterns {
    // 13-19 digits, optionally separated by spaces or dashes
    private static let creditCardPattern = #"[0-9]{4}[\s-]?[0-9]{4}[\s-]?[0-9]{4}[\s-]?[0-9]{1,7}"#

    // XXX-XX-XXXX
    private static let ssnPattern = #"[0-9]{3}-[0-9]{2}-[0-9]{4}"#

    // Standard email
    private static let emailPattern = #"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}"#

    // US phone formats
    private static let phonePattern = #"(\+1[\s-]?)?\(?[0-9]{3}\)?[\s.\-]?[0-9]{3}[\s.\-]?[0-9]{4}"#

    // Common API key formats
    private static let apiKeyPattern = #"(sk-[a-zA-Z0-9]{20,}|sk-proj-[a-zA-Z0-9\-_]{20,}|AKIA[0-9A-Z]{16}|ghp_[a-zA-Z0-9]{36}|pk_[a-zA-Z0-9]{20,}|xoxb-[0-9]+-[a-zA-Z0-9]+)"#

    private static let patterns: [(PIIType, String)] = [
        (.creditCard, creditCardPattern),
        (.ssn, ssnPattern),
        (.email, emailPattern),
        (.phone, phonePattern),
        (.apiKey, apiKeyPattern),
    ]

    public static func scan(_ text: String) -> [PIIMatch] {
        var matches: [PIIMatch] = []

        for (type, pattern) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let nsRange = NSRange(text.startIndex..., in: text)
            let results = regex.matches(in: text, range: nsRange)

            for result in results {
                guard let range = Range(result.range, in: text) else { continue }
                let value = String(text[range])

                if type == .creditCard && !luhnCheck(value) {
                    continue
                }

                matches.append(PIIMatch(type: type, value: value, range: range))
            }
        }

        return matches
    }

    public static func scanForSecrets(_ text: String, secrets: [String]) -> [PIIMatch] {
        var matches: [PIIMatch] = []
        let lowered = text.lowercased()

        for secret in secrets {
            let secretLower = secret.lowercased()
            var searchStart = lowered.startIndex

            while let range = lowered.range(of: secretLower, range: searchStart..<lowered.endIndex) {
                let originalRange = Range(uncheckedBounds: (
                    text.index(text.startIndex, offsetBy: lowered.distance(from: lowered.startIndex, to: range.lowerBound)),
                    text.index(text.startIndex, offsetBy: lowered.distance(from: lowered.startIndex, to: range.upperBound))
                ))
                matches.append(PIIMatch(type: .secretString, value: String(text[originalRange]), range: originalRange))
                searchStart = range.upperBound
            }
        }

        return matches
    }

    private static func luhnCheck(_ number: String) -> Bool {
        let digits = number.compactMap { $0.wholeNumberValue }
        guard digits.count >= 13 else { return false }

        var sum = 0
        for (index, digit) in digits.reversed().enumerated() {
            if index % 2 == 1 {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }
        return sum % 10 == 0
    }
}
