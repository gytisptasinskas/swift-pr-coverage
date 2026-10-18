import Core
import Foundation

/// Partly covered by AppTests: `totalText` and `add` are tested, `clear` and `tierLabel` are not.
final class CartModel {
    private(set) var items: [Int] = []
    private let formatter = PriceFormatter()
    private let calculator = Calculator()

    func add(cents: Int) {
        items.append(cents)
    }

    var totalText: String {
        let total = items.reduce(0) { calculator.add($0, $1) }
        return formatter.format(cents: total)
    }

    func clear() {
        items.removeAll()
    }

    var tierLabel: String {
        if items.count > 3 {
            return formatter.label(for: .premium)
        } else {
            return formatter.label(for: .free)
        }
    }
}
