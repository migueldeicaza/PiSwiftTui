import Foundation
import MiniTui
import PiSwiftAI
import PiSwiftAgent
import PiSwiftCodingAgent
import Testing
@testable import PiSwiftCodingAgentTui

private final class ClipboardTestResourceLoader: ResourceLoader {
    func getExtensions() -> ExtensionsResult { ExtensionsResult(paths: [], diagnostics: []) }
    func getSkills() -> (skills: [Skill], diagnostics: [ResourceDiagnostic]) { ([], []) }
    func getPrompts() -> (prompts: [PromptTemplate], diagnostics: [ResourceDiagnostic]) { ([], []) }
    func getThemes() -> (themes: [HookThemeInfo], diagnostics: [ResourceDiagnostic]) { ([], []) }
    func getAgentsFiles() -> [ContextFile] { [] }
    func getSystemPrompt() -> String? { nil }
    func getAppendSystemPrompt() -> [String] { [] }
    func getPathMetadata() -> [String: PathMetadata] { [:] }
    func extendResources(_ paths: ResourceExtensionPaths) {}
    func reload() async {}
}

private func makeClipboardTestSession(messages: [AgentMessage]) -> (AgentSession, String) {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("pi-tui-clipboard-test-\(UUID().uuidString)").path
    try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

    let agent = Agent()
    for message in messages {
        agent.appendMessage(message)
    }
    let authStorage = AuthStorage(URL(fileURLWithPath: tempDir).appendingPathComponent("auth.json").path)
    let session = AgentSession(config: AgentSessionConfig(
        agent: agent,
        sessionManager: SessionManager.inMemory(tempDir),
        settingsManager: SettingsManager.create(tempDir, tempDir),
        resourceLoader: ClipboardTestResourceLoader(),
        modelRegistry: ModelRegistry(authStorage, tempDir)
    ))
    return (session, tempDir)
}

private func assistantMessage(_ text: String) -> AgentMessage {
    .assistant(AssistantMessage(
        content: [.text(TextContent(text: text))],
        api: .anthropicMessages,
        provider: "anthropic",
        model: "test",
        usage: Usage(input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0),
        stopReason: .stop
    ))
}

@MainActor
@Test func copyCommandCopiesLastAssistantText() {
    initTheme("dark")
    let (session, tempDir) = makeClipboardTestSession(messages: [assistantMessage("  hello  ")])
    defer {
        session.dispose()
        try? FileManager.default.removeItem(atPath: tempDir)
    }
    let mode = InteractiveMode(session: session, version: "test")

    #expect(session.getLastAssistantText()?.trimmingCharacters(in: .whitespacesAndNewlines) == "hello")
    mode.handleCopyCommand()

    let rendered = mode.chatContainer.render(width: 120).joined(separator: "\n")
    #expect(rendered.contains("Copied last agent message to clipboard"))
}

@MainActor
@Test func copyCommandShowsErrorForEmptyHistory() {
    initTheme("dark")
    let (session, tempDir) = makeClipboardTestSession(messages: [])
    defer {
        session.dispose()
        try? FileManager.default.removeItem(atPath: tempDir)
    }
    let mode = InteractiveMode(session: session, version: "test")

    mode.handleCopyCommand()

    let rendered = mode.chatContainer.render(width: 120).joined(separator: "\n")
    #expect(rendered.contains("No agent messages to copy yet."))
}
