import Foundation
import MiniTui

/// Reusable countdown timer for dialog components.
/// Calls onTick every second with remaining seconds, and onExpire when timer reaches zero.
@MainActor
public final class CountdownTimer {
    private var timer: DispatchSourceTimer?
    private var remainingSeconds: Int
    private weak var tui: TUI?
    private let onTick: @MainActor (Int) -> Void
    private let onExpire: @MainActor () -> Void

    /// Creates a countdown timer.
    /// - Parameters:
    ///   - timeoutMs: Total timeout in milliseconds
    ///   - tui: Optional TUI instance for requesting renders
    ///   - onTick: Called every second with remaining seconds (also called immediately)
    ///   - onExpire: Called when timer reaches zero
    public init(
        timeoutMs: Int,
        tui: TUI? = nil,
        onTick: @escaping @MainActor (Int) -> Void,
        onExpire: @escaping @MainActor () -> Void
    ) {
        self.remainingSeconds = Int(ceil(Double(timeoutMs) / 1000.0))
        self.tui = tui
        self.onTick = onTick
        self.onExpire = onExpire

        // Call onTick immediately with initial value
        onTick(remainingSeconds)

        // Set up the timer
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timer.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        self.timer = timer
        timer.resume()
    }

    private func tick() {
        remainingSeconds -= 1
        onTick(remainingSeconds)
        tui?.requestRender()

        if remainingSeconds <= 0 {
            dispose()
            onExpire()
        }
    }

    /// Stops the timer and cleans up resources.
    /// Must be called to clean up the timer. The timer is not automatically
    /// disposed on deallocation.
    public func dispose() {
        timer?.cancel()
        timer = nil
    }
}
