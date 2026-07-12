import Foundation
import MiniTui
import PiSwiftAI
import PiSwiftCodingAgent

public final class HookMessageComponent: Container {
    private let message: HookMessage
    private let customRenderer: HookMessageRenderer?
    private let box: Box
    private var customComponent: Component?
    private var expanded = false

    public init(message: HookMessage, customRenderer: HookMessageRenderer? = nil) {
        self.message = message
        self.customRenderer = customRenderer
        self.box = Box(paddingX: 1, paddingY: 1, bgFn: { theme.bg(.customMessageBg, $0) })
        super.init()

        addChild(Spacer(1))
        rebuild()
    }

    public func setExpanded(_ expanded: Bool) {
        if self.expanded != expanded {
            self.expanded = expanded
            rebuild()
        }
    }

    public override func invalidate() {
        super.invalidate()
        rebuild()
    }

    private func rebuild() {
        if let customComponent {
            removeChild(customComponent)
            self.customComponent = nil
        }
        removeChild(box)

        if let customRenderer {
            let rendered = customRenderer(message, HookMessageRenderOptions(expanded: expanded), theme)
            if let component = rendered as? Component {
                customComponent = component
                addChild(component)
                return
            }
        }

        addChild(box)
        box.clear()

        let label = theme.fg(.customMessageLabel, "\u{001B}[1m[\(message.customType)]\u{001B}[22m")
        box.addChild(Text(label, paddingX: 0, paddingY: 0))
        box.addChild(Spacer(1))

        let text: String
        switch message.content {
        case .text(let value):
            text = value
        case .blocks(let blocks):
            text = blocks.compactMap { block in
                if case let .text(text) = block {
                    return text.text
                }
                return nil
            }.joined(separator: "\n")
        }

        var displayText = text
        if !expanded {
            let lines = displayText.split(separator: "\n", omittingEmptySubsequences: false)
            if lines.count > 5 {
                displayText = lines.prefix(5).joined(separator: "\n") + "\n..."
            }
        }

        let style = DefaultTextStyle(color: { theme.fg(.customMessageText, $0) })
        box.addChild(Markdown(displayText, paddingX: 0, paddingY: 0, theme: getMarkdownTheme(), defaultTextStyle: style))
    }
}
