import MiniTui
import Testing

@Test func truncateToWidthHandlesUnicode() {
    let message = "✔ script to run › dev $ concurrently \"vite\" \"node --import tsx ./"
    let width = 67
    let maxWidth = width - 2

    let truncated = truncateToWidth(message, maxWidth: maxWidth)
    let truncatedWidth = visibleWidth(truncated)

    #expect(truncatedWidth <= maxWidth)
}

@Test func truncateToWidthHandlesEmoji() {
    let message = "🎉 Celebration! 🚀 Launch 📦 Package ready for deployment now"
    let width = 40
    let maxWidth = width - 2

    let truncated = truncateToWidth(message, maxWidth: maxWidth)
    let truncatedWidth = visibleWidth(truncated)

    #expect(truncatedWidth <= maxWidth)
}

@Test func truncateToWidthHandlesMixedWidth() {
    let message = "Hello 世界 Test 你好 More text here that is long"
    let width = 30
    let maxWidth = width - 2

    let truncated = truncateToWidth(message, maxWidth: maxWidth)
    let truncatedWidth = visibleWidth(truncated)

    #expect(truncatedWidth <= maxWidth)
}

@Test func truncateToWidthNoTruncation() {
    let message = "Short message"
    let width = 50
    let maxWidth = width - 2

    let truncated = truncateToWidth(message, maxWidth: maxWidth)

    #expect(truncated == message)
    #expect(visibleWidth(truncated) <= maxWidth)
}

@Test func truncateToWidthAddsEllipsis() {
    let message = "This is a very long message that needs to be truncated"
    let width = 30
    let maxWidth = width - 2

    let truncated = truncateToWidth(message, maxWidth: maxWidth)

    #expect(truncated.contains("..."))
    #expect(visibleWidth(truncated) <= maxWidth)
}

@Test func truncateToWidthIssueCase() {
    let message = "✔ script to run › dev $ concurrently \"vite\" \"node --import tsx ./server.ts\""
    let terminalWidth = 67
    let cursorWidth = 2
    let maxWidth = terminalWidth - cursorWidth

    let truncated = truncateToWidth(message, maxWidth: maxWidth)
    let finalWidth = visibleWidth(truncated)

    #expect(finalWidth + cursorWidth <= terminalWidth)
}
