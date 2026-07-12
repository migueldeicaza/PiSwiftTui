import MiniTui
import Testing
import PiSwiftCodingAgent
import PiSwiftCodingAgentTui

@MainActor
private final class FakeUI: RenderRequesting {
    private(set) var renderRequests = 0

    func requestRender() {
        renderRequests += 1
    }
}

@MainActor
private final class DummyComponent: Component {
    func render(width: Int) -> [String] {
        ["OTHER"]
    }
}

@MainActor
private func renderLastLine(_ container: Container, width: Int = 120) -> String {
    guard let last = container.children.last else { return "" }
    return last.render(width: width).joined(separator: "\n")
}

@MainActor
@Test func showStatusCoalescesSequentialMessages() {
    initTheme("dark")
    let ui = FakeUI()
    let mode = InteractiveMode(chatContainer: Container(), ui: ui)

    mode.showStatus("STATUS_ONE")
    #expect(mode.chatContainer.children.count == 2)
    #expect(renderLastLine(mode.chatContainer).contains("STATUS_ONE"))

    mode.showStatus("STATUS_TWO")
    #expect(mode.chatContainer.children.count == 2)
    #expect(renderLastLine(mode.chatContainer).contains("STATUS_TWO"))
    #expect(!renderLastLine(mode.chatContainer).contains("STATUS_ONE"))
}

@MainActor
@Test func showStatusAppendsAfterOtherContent() {
    initTheme("dark")
    let ui = FakeUI()
    let mode = InteractiveMode(chatContainer: Container(), ui: ui)

    mode.showStatus("STATUS_ONE")
    #expect(mode.chatContainer.children.count == 2)

    mode.chatContainer.addChild(DummyComponent())
    #expect(mode.chatContainer.children.count == 3)

    mode.showStatus("STATUS_TWO")
    #expect(mode.chatContainer.children.count == 5)
    #expect(renderLastLine(mode.chatContainer).contains("STATUS_TWO"))
}
