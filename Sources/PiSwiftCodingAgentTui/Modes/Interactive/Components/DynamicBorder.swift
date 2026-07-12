import Foundation
import MiniTui
import PiSwiftCodingAgent

public final class DynamicBorder: Component {
    private let color: (String) -> String

    public init(color: @escaping (String) -> String = { theme.fg(.border, $0) }) {
        self.color = color
    }

    public func invalidate() {}

    public func render(width: Int) -> [String] {
        let line = String(repeating: "─", count: max(1, width))
        return [color(line)]
    }
}
