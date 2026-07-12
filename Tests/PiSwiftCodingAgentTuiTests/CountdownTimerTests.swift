import Foundation
import Testing
@testable import PiSwiftCodingAgentTui

// MARK: - CountdownTimer tests

@Test @MainActor func countdownTimerInitialTick() async {
    var tickedSeconds: [Int] = []
    var expired = false

    let timer = CountdownTimer(
        timeoutMs: 3000,
        tui: nil,
        onTick: { seconds in tickedSeconds.append(seconds) },
        onExpire: { expired = true }
    )

    // Should have called onTick immediately with initial value
    #expect(tickedSeconds == [3])
    #expect(expired == false)

    timer.dispose()
}

@Test @MainActor func countdownTimerCalculatesSecondsFromMs() async {
    var initialSeconds: Int?

    let timer = CountdownTimer(
        timeoutMs: 5500, // 5.5 seconds should round up to 6
        tui: nil,
        onTick: { seconds in
            if initialSeconds == nil {
                initialSeconds = seconds
            }
        },
        onExpire: {}
    )

    #expect(initialSeconds == 6)
    timer.dispose()
}

@Test @MainActor func countdownTimerTicksDown() async {
    var tickedSeconds: [Int] = []
    var expired = false

    let timer = CountdownTimer(
        timeoutMs: 2000,
        tui: nil,
        onTick: { seconds in tickedSeconds.append(seconds) },
        onExpire: { expired = true }
    )

    // Wait for 1.1 seconds to ensure at least one tick
    try? await Task.sleep(nanoseconds: 1_100_000_000)

    #expect(tickedSeconds.contains(2)) // Initial tick
    #expect(tickedSeconds.contains(1)) // After 1 second
    #expect(expired == false)

    timer.dispose()
}

@Test @MainActor func countdownTimerExpiresAtZero() async {
    var expired = false

    let timer = CountdownTimer(
        timeoutMs: 1000, // 1 second
        tui: nil,
        onTick: { _ in },
        onExpire: { expired = true }
    )

    // Wait for timer to expire (1 second + buffer)
    try? await Task.sleep(nanoseconds: 1_500_000_000)

    #expect(expired == true)

    // dispose is safe to call even after expiration
    timer.dispose()
}

@Test @MainActor func countdownTimerDisposeStopsTimer() async {
    var tickCount = 0

    let timer = CountdownTimer(
        timeoutMs: 5000,
        tui: nil,
        onTick: { _ in tickCount += 1 },
        onExpire: {}
    )

    // Initial tick
    #expect(tickCount == 1)

    // Dispose immediately
    timer.dispose()

    // Wait a bit
    try? await Task.sleep(nanoseconds: 1_500_000_000)

    // Should not have ticked after dispose
    #expect(tickCount == 1)
}

@Test @MainActor func countdownTimerDisposeIsIdempotent() async {
    let timer = CountdownTimer(
        timeoutMs: 5000,
        tui: nil,
        onTick: { _ in },
        onExpire: {}
    )

    // Multiple dispose calls should be safe
    timer.dispose()
    timer.dispose()
    timer.dispose()
}

@Test @MainActor func countdownTimerZeroTimeout() async {
    var tickedSeconds: [Int] = []
    var expired = false

    let timer = CountdownTimer(
        timeoutMs: 0,
        tui: nil,
        onTick: { seconds in tickedSeconds.append(seconds) },
        onExpire: { expired = true }
    )

    // Initial tick with 0 seconds
    #expect(tickedSeconds == [0])

    // Wait for first tick
    try? await Task.sleep(nanoseconds: 1_100_000_000)

    // Should have expired after going to -1
    #expect(expired == true)

    timer.dispose()
}
