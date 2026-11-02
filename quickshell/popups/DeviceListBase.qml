import QtQuick
BasePopup {
    id: list
    property bool listBlocked: false
    property var targetList: null
    function stepSelection(dir: int): void {
        stepListView(targetList, dir);
    }
    function activateRow(): void {
    }
    function forgetRow(): void {
    }
    function toggleEnabled(): void {
    }
    function toggleScan(): void {
    }
    function resetNav(): void {
        if (targetList)
            targetList.currentIndex = 0;
    }
    ListNavKeys {
        host: list
        navActive: !list.listBlocked
        step: dir => list.stepSelection(dir)
        confirm: () => list.activateRow()
        remove: () => list.forgetRow()
    }
    Shortcut { sequence: "s"; enabled: list.visible && !list.listBlocked; onActivated: list.toggleScan() }
    Shortcut { sequence: "e"; enabled: list.visible && !list.listBlocked; onActivated: list.toggleEnabled() }
}
