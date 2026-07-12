import Darwin
import Foundation
import MiniTui
import PiSwiftCodingAgent
import PiSwiftCodingAgentTui

public func selectSession(
    currentSessionsLoader: @escaping SessionsLoader,
    allSessionsLoader: @escaping SessionsLoader
) async -> String? {
    await withCheckedContinuation { continuation in
        Task { @MainActor in
            let ui = TUI(terminal: ProcessTerminal())
            var resolved = false

            let selector = SessionSelectorComponent(
                currentSessionsLoader: currentSessionsLoader,
                allSessionsLoader: allSessionsLoader,
                onSelect: { path in
                    guard !resolved else { return }
                    resolved = true
                    ui.stop()
                    continuation.resume(returning: path)
                },
                onCancel: {
                    guard !resolved else { return }
                    resolved = true
                    ui.stop()
                    continuation.resume(returning: nil)
                },
                onExit: {
                    ui.stop()
                    Darwin.exit(0)
                },
                requestRender: {
                    ui.requestRender()
                }
            )

            ui.addChild(selector)
            ui.setFocus(selector.getSessionList())
            ui.start()
        }
    }
}
