import Darwin
import Foundation
import MiniTui
import PiSwiftCodingAgent
import PiSwiftCodingAgentTui

public func selectConfig(
    resolvedPaths: ResolvedPaths,
    settingsManager: SettingsManager,
    cwd: String,
    agentDir: String
) async {
    await withCheckedContinuation { continuation in
        Task { @MainActor in
            initTheme(settingsManager.getTheme(), enableWatcher: true)
            let ui = TUI(terminal: ProcessTerminal())
            var resolved = false

            let selector = ConfigSelectorComponent(
                resolvedPaths: resolvedPaths,
                settingsManager: settingsManager,
                cwd: cwd,
                agentDir: agentDir,
                onClose: {
                    guard !resolved else { return }
                    resolved = true
                    ui.stop()
                    stopThemeWatcher()
                    continuation.resume()
                },
                onExit: {
                    ui.stop()
                    stopThemeWatcher()
                    Darwin.exit(0)
                },
                requestRender: {
                    ui.requestRender()
                }
            )

            ui.addChild(selector)
            ui.setFocus(selector.getResourceList())
            ui.start()
        }
    }
}
