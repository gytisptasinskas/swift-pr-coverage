import Testing
@testable import Core

struct CalculatorTests {
    @Test func add() {
        #expect(Calculator().add(2, 3) == 5)
    }

    @Test func divide() {
        #expect(Calculator().divide(6, by: 3) == 2)
        #expect(Calculator().divide(1, by: 0) == nil)
    }
}

struct PriceFormatterTests {
    @Test func format() {
        #expect(PriceFormatter().format(cents: 1205) == "€12.05")
    }

    @Test func label() {
        #expect(PriceFormatter().label(for: .premium) == "Premium")
        #expect(PriceFormatter().label(for: .standard) == "Standard")
    }
}
