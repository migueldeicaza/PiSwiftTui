import Foundation
import MiniTui
import PiSwiftCodingAgent

public final class ShowImagesSelectorComponent: Container {
    private let selectList: SelectList

    public init(currentValue: Bool, onSelect: @escaping (Bool) -> Void, onCancel: @escaping () -> Void) {
        let items: [SelectItem] = [
            SelectItem(value: "yes", label: "Yes", description: "Show images inline in terminal"),
            SelectItem(value: "no", label: "No", description: "Show text placeholder instead"),
        ]
        self.selectList = SelectList(items: items, maxVisible: 5, theme: getSelectListTheme())

        super.init()

        addChild(DynamicBorder())

        selectList.setSelectedIndex(currentValue ? 0 : 1)
        selectList.onSelect = { item in
            onSelect(item.value == "yes")
        }
        selectList.onCancel = onCancel

        addChild(selectList)
        addChild(DynamicBorder())
    }

    public func getSelectList() -> SelectList {
        selectList
    }
}
