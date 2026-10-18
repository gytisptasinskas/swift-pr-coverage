import XCTest
@testable import App

final class CartModelTests: XCTestCase {
    func testTotalText() {
        let model = CartModel()
        model.add(cents: 150)
        model.add(cents: 250)
        XCTAssertEqual(model.totalText, "€4.00")
    }
}
