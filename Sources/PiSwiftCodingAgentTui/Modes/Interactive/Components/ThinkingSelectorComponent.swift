import Foundation
import MiniTui
import PiSwiftAgent
import PiSwiftCodingAgent

private let thinkingDescriptions: [ThinkingLevel: String] = [
    .off: "No reasoning",
    .minimal: "Very brief reasoning (~1k tokens)",
    .low: "Light reasoning (~2k tokens)",
    .medium: "Moderate reasoning (~8k tokens)",
    .high: "Deep reasoning (~16k tokens)",
    .xhigh: "Maximum reasoning (~32k tokens)",
]

public final class ThinkingSelectorComponent: Container {
    private let selectList: SelectList

    public init(
        currentLevel: ThinkingLevel,
        availableLevels: [ThinkingLevel],
        onSelect: @escaping (ThinkingLevel) -> Void,
        onCancel: @escaping () -> Void
    ) {
        let items: [SelectItem] = availableLevels.map { level in
            SelectItem(value: level.rawValue, label: level.rawValue, description: thinkingDescriptions[level])
        }
        self.selectList = SelectList(items: items, maxVisible: items.count, theme: getSelectListTheme())
        super.init()

        addChild(DynamicBorder())

        if let idx = items.firstIndex(where: { $0.value == currentLevel.rawValue }) {
            selectList.setSelectedIndex(idx)
        }

        selectList.onSelect = { item in
            if let level = ThinkingLevel(rawValue: item.value) {
                onSelect(level)
            }
        }
        selectList.onCancel = onCancel

        addChild(selectList)
        addChild(DynamicBorder())
    }

    public func getSelectList() -> SelectList {
        selectList
    }
}
