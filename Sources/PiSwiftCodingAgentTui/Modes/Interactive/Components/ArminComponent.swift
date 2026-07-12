import Foundation
import MiniTui
import PiSwiftCodingAgent

public final class ArminComponent: Component {
    public init() {}

    public func invalidate() {}

    public func render(width: Int) -> [String] {
        let message = "ARMIN SAYS HI"
        let padded = " " + message
        let padRight = max(0, width - visibleWidth(padded))
        return [theme.fg(.accent, padded) + String(repeating: " ", count: padRight)]
    }
}
