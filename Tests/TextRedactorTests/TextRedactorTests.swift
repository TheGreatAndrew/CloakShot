import Testing
@testable import TextRedactor
@testable import Shared

@Suite("TextRedactor")
struct TextRedactorTests {

    @Test func detectsSecretStrings() {
        let config = CloakConfig(secretStrings: ["4111-1111-1111-1111", "john@secret.com"])
        let redactor = TextRedactor(config: config)

        let texts = "Your card is 4111-1111-1111-1111 and email is john@secret.com"
        let matches = redactor.scanText(texts)

        #expect(matches.count >= 2)
    }

    @Test func noMatchesWhenClean() {
        let config = CloakConfig(secretStrings: ["supersecret"])
        let redactor = TextRedactor(config: config)

        let matches = redactor.scanText("Hello world, nothing sensitive here")
        #expect(matches.isEmpty)
    }

    @Test func redactsText() {
        let config = CloakConfig(secretStrings: ["mypassword123"])
        let redactor = TextRedactor(config: config)

        let result = redactor.redactText("Login with mypassword123 to continue")
        #expect(result.contains("[SECRET_STRING]"))
        #expect(!result.contains("mypassword123"))
    }

    @Test func detectsEmail() {
        let config = CloakConfig()
        let redactor = TextRedactor(config: config)

        let matches = redactor.scanText("Send to user@example.com please")
        let emailMatches = matches.filter { $0.type == .email }
        #expect(emailMatches.count == 1)
        #expect(emailMatches.first?.value == "user@example.com")
    }

    @Test func detectsSSN() {
        let config = CloakConfig()
        let redactor = TextRedactor(config: config)

        let matches = redactor.scanText("SSN: 123-45-6789")
        let ssnMatches = matches.filter { $0.type == .ssn }
        #expect(ssnMatches.count == 1)
    }

    @Test func detectsAPIKeys() {
        let config = CloakConfig()
        let redactor = TextRedactor(config: config)

        let matches = redactor.scanText("Key: sk-proj-abcdefghijklmnopqrstuvwx")
        let keyMatches = matches.filter { $0.type == .apiKey }
        #expect(keyMatches.count == 1)
    }

    @Test func caseInsensitiveSecretMatching() {
        let config = CloakConfig(secretStrings: ["MySecret"])
        let redactor = TextRedactor(config: config)

        let matches = redactor.scanText("the value is mysecret here")
        let secretMatches = matches.filter { $0.type == .secretString }
        #expect(secretMatches.count == 1)
    }
}

@Suite("PIIPatterns")
struct PIIPatternsTests {

    @Test func creditCardWithLuhn() {
        let matches = PIIPatterns.scan("Card: 4111 1111 1111 1111")
        #expect(matches.count == 1)
        #expect(matches.first?.type == .creditCard)
    }

    @Test func invalidCreditCardFailsLuhn() {
        let matches = PIIPatterns.scan("Not a card: 1234 5678 9012 3456")
        let ccMatches = matches.filter { $0.type == .creditCard }
        #expect(ccMatches.isEmpty)
    }

    @Test func phoneNumber() {
        let matches = PIIPatterns.scan("Call (555) 123-4567")
        let phoneMatches = matches.filter { $0.type == .phone }
        #expect(phoneMatches.count == 1)
    }

    @Test func multiplePatterns() {
        let text = "Email me at test@example.com, SSN 123-45-6789, call 555-123-4567"
        let matches = PIIPatterns.scan(text)
        let types = Set(matches.map(\.type))
        #expect(types.contains(.email))
        #expect(types.contains(.ssn))
        #expect(types.contains(.phone))
    }
}
