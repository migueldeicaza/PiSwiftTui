import Foundation
import MiniTui
import PiSwiftCodingAgent

public struct MermaidMarkdownTransformOptions: Sendable {
    public var enabled: Bool
    public var renderWhileStreaming: Bool
    public var isStreaming: Bool
    public var theme: Theme?

    public init(
        enabled: Bool = true,
        renderWhileStreaming: Bool = true,
        isStreaming: Bool = false,
        theme: Theme? = nil
    ) {
        self.enabled = enabled
        self.renderWhileStreaming = renderWhileStreaming
        self.isStreaming = isStreaming
        self.theme = theme
    }
}

private struct MermaidNode: Sendable {
    let id: String
    let label: String
}

private struct MermaidDiagram: Sendable {
    enum Direction: Sendable {
        case horizontal
        case vertical
    }

    let direction: Direction
    let nodes: [MermaidNode]
}

private struct MermaidFence {
    let character: Character
    let length: Int
    let start: Int
    let end: Int
    let body: String
    let closed: Bool
}

/// Create a MiniTui Markdown source transform for Mermaid fenced code blocks.
public func createMermaidMarkdownTransform(
    options: MermaidMarkdownTransformOptions
) -> MarkdownSourceTransform {
    { source, width in
        guard options.enabled,
              !options.isStreaming || options.renderWhileStreaming else {
            return source
        }
        return transformMermaidFences(source, width: width, options: options)
    }
}

private func transformMermaidFences(
    _ source: String,
    width: Int,
    options: MermaidMarkdownTransformOptions
) -> String {
    let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    var output: [String] = []
    var index = 0

    while index < lines.count {
        guard let fence = mermaidFence(lines: lines, start: index, allowUnclosed: options.isStreaming) else {
            output.append(lines[index])
            index += 1
            continue
        }

        let original = lines[fence.start...fence.end].joined(separator: "\n")
        guard let diagram = parseMermaidDiagram(fence.body),
              let rendered = renderMermaidDiagram(diagram, theme: options.theme),
              rendered.allSatisfy({ visibleWidth($0) <= width }) else {
            output.append(original)
            index = fence.end + 1
            continue
        }

        output.append(rendered.map(markdownCodeSpan).joined(separator: "  \n"))
        index = fence.end + 1
    }

    return output.joined(separator: "\n")
}

private func mermaidFence(lines: [String], start: Int, allowUnclosed: Bool) -> MermaidFence? {
    let line = lines[start]
    let leadingSpaces = line.prefix { $0 == " " }.count
    guard leadingSpaces <= 3 else { return nil }
    let trimmed = String(line.dropFirst(leadingSpaces))
    guard let character = trimmed.first, character == "`" || character == "~" else { return nil }
    let length = trimmed.prefix { $0 == character }.count
    guard length >= 3 else { return nil }
    let info = trimmed.dropFirst(length).trimmingCharacters(in: .whitespaces)
    guard info.split(whereSeparator: \Character.isWhitespace).first?.lowercased() == "mermaid" else {
        return nil
    }

    var end = start + 1
    while end < lines.count {
        let candidate = lines[end].trimmingCharacters(in: .whitespaces)
        let candidateLength = candidate.prefix { $0 == character }.count
        if candidateLength >= length,
           candidate.dropFirst(candidateLength).trimmingCharacters(in: .whitespaces).isEmpty {
            return MermaidFence(
                character: character,
                length: length,
                start: start,
                end: end,
                body: lines[(start + 1)..<end].joined(separator: "\n"),
                closed: true
            )
        }
        end += 1
    }

    guard allowUnclosed else { return nil }
    return MermaidFence(
        character: character,
        length: length,
        start: start,
        end: lines.count - 1,
        body: lines[(start + 1)...].joined(separator: "\n"),
        closed: false
    )
}

private func parseMermaidDiagram(_ source: String) -> MermaidDiagram? {
    let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty && !$0.hasPrefix("%%") }
    guard let header = lines.first else { return nil }
    let headerParts = header.split(whereSeparator: \Character.isWhitespace).map(String.init)
    guard headerParts.count >= 2,
          headerParts[0].lowercased() == "flowchart" || headerParts[0].lowercased() == "graph" else {
        return nil
    }

    let direction: MermaidDiagram.Direction
    switch headerParts[1].uppercased() {
    case "LR", "RL": direction = .horizontal
    case "TB", "TD", "BT": direction = .vertical
    default: return nil
    }

    var nodes: [MermaidNode] = []
    var nodeIndices: [String: Int] = [:]
    var edges: [(String, String)] = []

    func addNode(_ token: String) -> String? {
        guard let node = parseMermaidNode(token) else { return nil }
        if let existing = nodeIndices[node.id] {
            if nodes[existing].label == nodes[existing].id, node.label != node.id {
                nodes[existing] = node
            }
        } else {
            nodeIndices[node.id] = nodes.count
            nodes.append(node)
        }
        return node.id
    }

    for line in lines.dropFirst() {
        guard let arrowRange = mermaidArrowRange(in: line) else { return nil }
        let left = String(line[..<arrowRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        var right = String(line[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        if right.hasPrefix("|") {
            guard let close = right.dropFirst().firstIndex(of: "|") else { return nil }
            right = String(right[right.index(after: close)...]).trimmingCharacters(in: .whitespaces)
        }
        guard let leftID = addNode(left), let rightID = addNode(right) else { return nil }
        edges.append((leftID, rightID))
    }

    guard !edges.isEmpty, nodes.count == edges.count + 1 else { return nil }
    for index in edges.indices {
        guard edges[index].0 == nodes[index].id, edges[index].1 == nodes[index + 1].id else {
            return nil
        }
    }

    if headerParts[1].uppercased() == "RL" || headerParts[1].uppercased() == "BT" {
        nodes.reverse()
    }
    return MermaidDiagram(direction: direction, nodes: nodes)
}

private func mermaidArrowRange(in line: String) -> Range<String.Index>? {
    for arrow in ["-->", "==>", "-.->"] {
        if let range = line.range(of: arrow) { return range }
    }
    return nil
}

private func parseMermaidNode(_ token: String) -> MermaidNode? {
    let trimmed = token.trimmingCharacters(in: .whitespaces)
    guard let first = trimmed.first, first.isLetter || first == "_" else { return nil }
    let id = trimmed.prefix { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    guard !id.isEmpty else { return nil }
    let remainder = trimmed.dropFirst(id.count).trimmingCharacters(in: .whitespaces)
    if remainder.isEmpty {
        return MermaidNode(id: String(id), label: String(id))
    }

    let pairs: [(Character, Character)] = [("[", "]"), ("(", ")"), ("{", "}")]
    guard let opening = remainder.first,
          let closing = pairs.first(where: { $0.0 == opening })?.1,
          remainder.last == closing else {
        return nil
    }
    var label = String(remainder.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
    if label.hasPrefix("\"") && label.hasSuffix("\"") && label.count >= 2 {
        label = String(label.dropFirst().dropLast())
    }
    guard !label.isEmpty, !label.contains("[") && !label.contains("]") else { return nil }
    return MermaidNode(id: String(id), label: label)
}

private func renderMermaidDiagram(_ diagram: MermaidDiagram, theme: Theme?) -> [String]? {
    guard !diagram.nodes.isEmpty else { return nil }
    switch diagram.direction {
    case .horizontal:
        return renderHorizontalMermaid(diagram.nodes, theme: theme)
    case .vertical:
        return renderVerticalMermaid(diagram.nodes, theme: theme)
    }
}

private func renderHorizontalMermaid(_ nodes: [MermaidNode], theme: Theme?) -> [String] {
    let tops = nodes.map { styledBorder("┌" + String(repeating: "─", count: $0.label.count + 2) + "┐", theme) }
    let bottoms = nodes.map { styledBorder("└" + String(repeating: "─", count: $0.label.count + 2) + "┘", theme) }
    var middle = ""
    for index in nodes.indices {
        let node = nodes[index]
        middle += styledBorder("│", theme) + " " + styledText(node.label, theme) + " "
        if index == nodes.count - 1 {
            middle += styledBorder("│", theme)
        } else {
            middle += styledBorder("├", theme) + styledEdge("───▶", theme)
        }
    }
    return [tops.joined(separator: "    "), middle, bottoms.joined(separator: "    ")]
}

private func renderVerticalMermaid(_ nodes: [MermaidNode], theme: Theme?) -> [String] {
    let maxWidth = nodes.map { $0.label.count + 2 }.max() ?? 2
    var lines: [String] = []
    for index in nodes.indices {
        let node = nodes[index]
        let left = (maxWidth - node.label.count) / 2
        let right = maxWidth - node.label.count - left
        lines.append(styledBorder("┌" + String(repeating: "─", count: maxWidth) + "┐", theme))
        lines.append(
            styledBorder("│", theme)
                + String(repeating: " ", count: left)
                + styledText(node.label, theme)
                + String(repeating: " ", count: right)
                + styledBorder("│", theme)
        )
        lines.append(styledBorder("└" + String(repeating: "─", count: maxWidth) + "┘", theme))
        if index < nodes.count - 1 {
            let indent = String(repeating: " ", count: (maxWidth + 1) / 2)
            lines.append(indent + styledEdge("│", theme))
            lines.append(indent + styledEdge("▼", theme))
        }
    }
    return lines
}

private func styledBorder(_ text: String, _ theme: Theme?) -> String {
    theme?.fg(.borderMuted, text) ?? text
}

private func styledText(_ text: String, _ theme: Theme?) -> String {
    theme?.fg(.text, text) ?? text
}

private func styledEdge(_ text: String, _ theme: Theme?) -> String {
    theme?.fg(.accent, text) ?? text
}

private func markdownCodeSpan(_ line: String) -> String {
    let content = line.isEmpty ? "\u{00A0}" : line
    var longestRun = 0
    var currentRun = 0
    for character in content {
        if character == "`" {
            currentRun += 1
            longestRun = max(longestRun, currentRun)
        } else {
            currentRun = 0
        }
    }
    let fence = String(repeating: "`", count: longestRun + 1)
    let padding = content.hasPrefix("`") || content.hasSuffix("`") ? " " : ""
    return fence + padding + content + padding + fence
}
