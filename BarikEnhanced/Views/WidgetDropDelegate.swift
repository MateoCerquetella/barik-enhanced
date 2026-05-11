import SwiftUI

struct WidgetDropDelegate: DropDelegate {
    let item: TomlWidgetItem
    let items: [TomlWidgetItem]
    @Binding var draggedItem: TomlWidgetItem?
    let onReorder: ([TomlWidgetItem]) -> Void

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem,
              draggedItem.instanceID != item.instanceID,
              let fromIndex = items.firstIndex(where: { $0.instanceID == draggedItem.instanceID }),
              let toIndex = items.firstIndex(where: { $0.instanceID == item.instanceID })
        else { return }

        var updatedItems = items
        withAnimation(.spring(duration: 0.2)) {
            updatedItems.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
        onReorder(updatedItems)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

struct EdgeDropDelegate: DropDelegate {
    let edge: Edge
    let items: [TomlWidgetItem]
    @Binding var draggedItem: TomlWidgetItem?
    let onReorder: ([TomlWidgetItem]) -> Void

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem,
              let fromIndex = items.firstIndex(where: { $0.instanceID == draggedItem.instanceID })
        else { return }

        var updatedItems = items
        let toIndex = edge == .leading ? 0 : updatedItems.count - 1

        if fromIndex != toIndex {
            withAnimation(.spring(duration: 0.2)) {
                updatedItems.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: edge == .leading ? 0 : updatedItems.count)
            }
            onReorder(updatedItems)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
