import Foundation

/// Partly covered: `format` is tested, `discounted` and the `.free` branch are not.
public struct PriceFormatter {
    public enum Tier {
        case free
        case standard
        case premium
    }

    public init() {}

    public func format(cents: Int) -> String {
        let euros = cents / 100
        let rest = cents % 100
        return "€\(euros).\(rest < 10 ? "0" : "")\(rest)"
    }

    public func label(for tier: Tier) -> String {
        switch tier {
        case .free:
            return "Free"
        case .standard:
            return "Standard"
        case .premium:
            return "Premium"
        }
    }

    public func discounted(cents: Int, percent: Int) -> Int {
        let clamped = min(max(percent, 0), 100)
        let values = [cents].map { value in
            value - value * clamped / 100
        }
        return values[0]
    }

    public func bundledGreeting() -> String? {
        guard let url = Bundle.module.url(forResource: "greeting", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
