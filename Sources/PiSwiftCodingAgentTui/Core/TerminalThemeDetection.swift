import Foundation
import MiniTui

@MainActor
public protocol TerminalThemeProbing: AnyObject {
    func queryTerminalColorScheme(timeoutMs: Int) async -> TerminalColorScheme?
    func queryTerminalBackgroundColor(timeoutMs: Int) async -> RgbColor?
}

extension TUI: TerminalThemeProbing {}

public func terminalThemeFromEnvironment(
    _ environment: [String: String] = ProcessInfo.processInfo.environment
) -> TerminalColorScheme {
    guard let colorFgBg = environment["COLORFGBG"] else { return .dark }
    let parts = colorFgBg.split(separator: ";")
    guard parts.count >= 2, let background = Int(parts[1]) else { return .dark }
    return background < 8 ? .dark : .light
}

public func terminalTheme(for color: RgbColor) -> TerminalColorScheme {
    func linear(_ channel: Int) -> Double {
        let value = Double(channel) / 255
        return value <= 0.03928
            ? value / 12.92
            : pow((value + 0.055) / 1.055, 2.4)
    }

    let luminance = 0.2126 * linear(color.r)
        + 0.7152 * linear(color.g)
        + 0.0722 * linear(color.b)
    return luminance >= 0.5 ? .light : .dark
}

@MainActor
public func detectTerminalTheme(
    ui: any TerminalThemeProbing,
    timeoutMs: Int = 100,
    environment: [String: String] = ProcessInfo.processInfo.environment
) async -> TerminalColorScheme {
    let colorSchemeTask = Task { @MainActor in
        await ui.queryTerminalColorScheme(timeoutMs: timeoutMs)
    }
    let backgroundColorTask = Task { @MainActor in
        await ui.queryTerminalBackgroundColor(timeoutMs: timeoutMs)
    }
    let reportedScheme = await colorSchemeTask.value
    let reportedBackground = await backgroundColorTask.value

    if let reportedScheme {
        return reportedScheme
    }
    if let reportedBackground {
        return terminalTheme(for: reportedBackground)
    }
    return terminalThemeFromEnvironment(environment)
}
