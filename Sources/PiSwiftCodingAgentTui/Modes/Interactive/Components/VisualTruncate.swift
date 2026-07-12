import Foundation
import MiniTui
import PiSwiftCodingAgent

public struct VisualTruncateResult: Sendable {
    public var visualLines: [String]
    public var skippedCount: Int

    public init(visualLines: [String], skippedCount: Int) {
        self.visualLines = visualLines
        self.skippedCount = skippedCount
    }
}

@MainActor
public func truncateToVisualLines(
    _ text: String,
    maxVisualLines: Int,
    width: Int,
    paddingX: Int = 0
) -> VisualTruncateResult {
    guard !text.isEmpty else {
        return VisualTruncateResult(visualLines: [], skippedCount: 0)
    }

    let tempText = Text(text, paddingX: paddingX, paddingY: 0)
    let allLines = tempText.render(width: width)

    if allLines.count <= maxVisualLines {
        return VisualTruncateResult(visualLines: allLines, skippedCount: 0)
    }

    let truncated = Array(allLines.suffix(maxVisualLines))
    let skipped = allLines.count - maxVisualLines
    return VisualTruncateResult(visualLines: truncated, skippedCount: skipped)
}
