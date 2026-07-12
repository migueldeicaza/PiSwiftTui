import MiniTui
import PiSwiftCodingAgent

@inline(__always) func isArrowUp(_ data: String) -> Bool {
    matchesKey(data, Key.up)
}

@inline(__always) func isArrowDown(_ data: String) -> Bool {
    matchesKey(data, Key.down)
}

@inline(__always) func isEnter(_ data: String) -> Bool {
    matchesKey(data, Key.enter) || matchesKey(data, Key.return)
}

@inline(__always) func isEscape(_ data: String) -> Bool {
    matchesKey(data, Key.escape) || matchesKey(data, Key.esc)
}

@inline(__always) func isCtrlC(_ data: String) -> Bool {
    matchesKey(data, Key.ctrl("c"))
}

@inline(__always) func isCtrlG(_ data: String) -> Bool {
    matchesKey(data, Key.ctrl("g"))
}

@inline(__always) func isCtrlZ(_ data: String) -> Bool {
    matchesKey(data, Key.ctrl("z"))
}

@inline(__always) func isCtrlT(_ data: String) -> Bool {
    matchesKey(data, Key.ctrl("t"))
}

@inline(__always) func isCtrlL(_ data: String) -> Bool {
    matchesKey(data, Key.ctrl("l"))
}

@inline(__always) func isCtrlU(_ data: String) -> Bool {
    matchesKey(data, Key.ctrl("u"))
}

@inline(__always) func isCtrlO(_ data: String) -> Bool {
    matchesKey(data, Key.ctrl("o"))
}

@inline(__always) func isCtrlP(_ data: String) -> Bool {
    matchesKey(data, Key.ctrl("p"))
}

@inline(__always) func isShiftCtrlP(_ data: String) -> Bool {
    matchesKey(data, Key.shiftCtrl("p")) || matchesKey(data, Key.ctrlShift("p"))
}

@inline(__always) func isAltEnter(_ data: String) -> Bool {
    matchesKey(data, Key.alt("enter"))
}

@inline(__always) func isShiftTab(_ data: String) -> Bool {
    matchesKey(data, Key.shift("tab"))
}

@inline(__always) func isCtrlD(_ data: String) -> Bool {
    matchesKey(data, Key.ctrl("d"))
}

@inline(__always) func isBackspace(_ data: String) -> Bool {
    matchesKey(data, Key.backspace)
}
