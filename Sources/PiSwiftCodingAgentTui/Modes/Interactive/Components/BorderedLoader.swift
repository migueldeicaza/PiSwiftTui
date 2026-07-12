import Foundation
import MiniTui
import PiSwiftCodingAgent

@MainActor
public final class BorderedLoader: Container {
    private let loader: CancellableLoader

    public init(tui: TUI, theme: Theme, message: String) {
        let borderColor: (String) -> String = { theme.fg(.border, $0) }
        self.loader = CancellableLoader(
            ui: tui,
            spinnerColorFn: { theme.fg(.accent, $0) },
            messageColorFn: { theme.fg(.muted, $0) },
            message: message
        )
        super.init()

        addChild(DynamicBorder(color: borderColor))
        addChild(loader)
        addChild(Spacer(1))
        addChild(Text(theme.fg(.muted, "esc cancel"), paddingX: 1, paddingY: 0))
        addChild(Spacer(1))
        addChild(DynamicBorder(color: borderColor))
    }

    public var signal: CancellationSignal {
        loader.signal
    }

    public var onAbort: (() -> Void)? {
        get { loader.onAbort }
        set { loader.onAbort = newValue }
    }

    public override func handleInput(_ data: String) {
        loader.handleInput(data)
    }

    public func dispose() {
        loader.dispose()
    }
}
