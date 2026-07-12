import Foundation
import Testing
import MiniTui
@testable import PiSwiftCodingAgent
@testable import PiSwiftCodingAgentTui

// MARK: - formatKeys tests

@Test func formatKeysEmptyArray() {
    let result = formatKeys([])
    #expect(result == "")
}

@Test func formatKeysSingleKey() {
    let result = formatKeys(["ctrl+c"])
    #expect(result == "ctrl+c")
}

@Test func formatKeysMultipleKeys() {
    let result = formatKeys(["ctrl+c", "escape"])
    #expect(result == "ctrl+c/escape")
}

@Test func formatKeysThreeKeys() {
    let result = formatKeys(["a", "b", "c"])
    #expect(result == "a/b/c")
}

// MARK: - editorKey tests

@Test func editorKeyReturnsFormattedString() {
    // Using a common editor action
    let result = editorKey(.selectConfirm)
    // Should return non-empty string (actual value depends on default keybindings)
    #expect(!result.isEmpty)
}

// MARK: - appKey tests

@Test func appKeyReturnsFormattedString() {
    let keybindings = KeybindingsManager.inMemory()
    let result = appKey(keybindings, .interrupt)
    // Default binding for interrupt is escape
    #expect(result == "escape")
}

@Test func appKeyWithCustomBinding() {
    let config: KeybindingsConfig = ["interrupt": ["ctrl+c", "escape"]]
    let keybindings = KeybindingsManager.inMemory(config: config)
    let result = appKey(keybindings, .interrupt)
    #expect(result == "ctrl+c/escape")
}

// MARK: - keyHint tests

@Test func keyHintFormatsWithDimKeyAndMutedDescription() {
    let result = keyHint(.selectConfirm, "to confirm")
    // Result should contain the description text
    #expect(result.contains("to confirm"))
    // Result should contain ANSI escape codes (for dim/muted coloring)
    #expect(result.contains("\u{001B}["))
}

// MARK: - appKeyHint tests

@Test func appKeyHintFormatsWithDimKeyAndMutedDescription() {
    let keybindings = KeybindingsManager.inMemory()
    let result = appKeyHint(keybindings, .expandTools, "to expand tools")
    // Result should contain the description text
    #expect(result.contains("to expand tools"))
    // Result should contain the key (ctrl+o by default)
    #expect(result.contains("ctrl+o"))
}

// MARK: - rawKeyHint tests

@Test func rawKeyHintFormatsWithDimKeyAndMutedDescription() {
    let result = rawKeyHint("↑↓", "navigate")
    // Result should contain the key
    #expect(result.contains("↑↓"))
    // Result should contain the description
    #expect(result.contains("navigate"))
    // Result should contain ANSI escape codes
    #expect(result.contains("\u{001B}["))
}

@Test func rawKeyHintWithEmptyKey() {
    let result = rawKeyHint("", "no key")
    #expect(result.contains("no key"))
}

@Test func rawKeyHintWithEmptyDescription() {
    let result = rawKeyHint("ctrl+s", "")
    #expect(result.contains("ctrl+s"))
}
