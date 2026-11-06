import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../../components"
import "../../services" as Services

Rectangle {
    id: root
    required property var popup

    property bool expanded: false
    property int selection: 0
    property var currentMenu: null
    property var menuOwner: null
    property var menuStack: []

    readonly property bool inMenu: currentMenu !== null
    readonly property var entries: inMenu ? menuOpener.children.values : SystemTray.items.values
    readonly property int entryCount: entries.length
    readonly property int listCap: 6 * 28 + 5 * Services.Theme.listSpacing

    readonly property int listHeight: {
        if (!expanded || entryCount === 0)
            return 0;
        let h = -Services.Theme.listSpacing;
        for (const e of entries)
            h += rowHeight(e) + Services.Theme.listSpacing;
        return h;
    }

    visible: entryCount > 0
    width: parent.width
    readonly property bool collapsedHover: trayArea.containsMouse
    color: popup.selectedKind() === "tray" ? Services.Theme.activeBg : root.collapsedHover ? Services.Theme.hoverBg : Services.Theme.surface
    border.width: popup.selectedKind() === "tray" ? 1 : 0
    border.color: root.collapsedHover ? Services.Theme.fg : Services.Theme.accent
    height: visible && popup.visible ? (expanded ? shellCol.implicitHeight : Services.Theme.rowHeight) : 0
    clip: true

    Connections {
        target: root.popup
        function onVisibleChanged() {
            if (!root.popup.visible)
                root.reset()
        }
    }

    onSelectionChanged: {
        if (expanded)
            entryList.positionViewAtIndex(selection, ListView.Contain)
    }

    QsMenuOpener {
        id: menuOpener
        menu: root.currentMenu
    }

    function reset() {
        expanded = false
        selection = 0
        currentMenu = null
        menuOwner = null
        menuStack = []
    }

    function expand() {
        expanded = true
        clampSelection()
    }

    function moveInList(dir: int) {
        if (entryCount === 0)
            return;
        let i = selection;
        for (let step = 0; step < entryCount; step++) {
            i = (i + dir + entryCount) % entryCount;
            if (selectable(entries[i])) {
                selection = i;
                return;
            }
        }
    }

    function activate() {
        if (!expanded) {
            expand();
            return;
        }

        const e = entries[selection];
        if (!e)
            return;

        if (!inMenu) {
            if (e.hasMenu) {
                openMenuFor(e);
            } else {
                try {
                    if (e.onlyMenu && typeof e.secondaryActivate === "function")
                        e.secondaryActivate();
                    else
                        e.activate();
                } catch (_) {}
                reset();
            }
        } else {
            if (e.hasChildren) {
                diveSubmenu(e);
            } else {
                try {
                    e.triggered();
                } catch (_) {}
                reset();
            }
        }
    }

    function forward() {
        if (!expanded) {
            expand();
            return;
        }

        const e = entries[selection];
        if (!e)
            return;

        if (!inMenu && e.hasMenu) {
            openMenuFor(e);
        } else if (inMenu && e.hasChildren) {
            diveSubmenu(e);
        }
    }

    function back() {
        if (!expanded)
            return false;

        if (menuStack.length > 0) {
            const level = menuStack[menuStack.length - 1];
            menuStack = menuStack.slice(0, -1);
            currentMenu = level.menu;
            selection = 0;
            clampSelection();
        } else if (inMenu) {
            currentMenu = null;
            menuOwner = null;
            selection = 0;
            clampSelection();
        } else {
            reset();
        }
        return true;
    }

    function selectable(e: var): bool {
        if (!e)
            return false;
        if (inMenu)
            return !e.isSeparator && e.enabled !== false;
        return true;
    }

    function clean(text: string): string {
        return (text ?? "").replace(/&([^&])/g, "$1").trim();
    }

    function rowHeight(e: var): int {
        return (e?.isSeparator ?? false) ? 6 : 28;
    }

    function labelFor(e: var): string {
        if (!e)
            return "";
        if (inMenu)
            return clean(e.text);
        return trayLabel(e);
    }

    function trayLabel(e: var): string {
        if (!e)
            return "";
        for (const s of [clean(e.tooltipTitle), clean(e.title), clean(e.id)]) {
            if (s !== "")
                return s;
        }
        return "";
    }

    function clampSelection() {
        if (entryCount === 0) {
            selection = 0;
            return;
        }
        if (selection >= entryCount)
            selection = entryCount - 1;
        if (!selectable(entries[selection])) {
            for (let i = 0; i < entryCount; i++) {
                if (selectable(entries[i])) {
                    selection = i;
                    return;
                }
            }
        }
    }

    function openMenuFor(item: var) {
        if (!item || !item.hasMenu)
            return;
        menuOwner = item;
        menuStack = [];
        currentMenu = item.menu;
        selection = 0;
        clampSelection();
    }

    function diveSubmenu(entry: var) {
        if (!entry || !entry.hasChildren)
            return;
        menuStack = [...menuStack, { menu: currentMenu, label: labelFor(entry) }];
        currentMenu = entry;
        selection = 0;
        clampSelection();
    }

    MouseArea {
        id: trayArea
        anchors.fill: parent
        visible: !root.expanded
        enabled: visible && root.popup.visible
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expand()
    }

    Column {
        id: shellCol
        width: parent.width
        spacing: Services.Theme.listSpacing

        HintText {
            visible: root.expanded && root.inMenu
            horizontalAlignment: Text.AlignLeft
            leftPadding: 8
            topPadding: 4
            text: [root.trayLabel(root.menuOwner), ...root.menuStack.map(s => s.label)].join(" / ")
            color: root.menuStack.length > 0 ? Services.Theme.dim : Services.Theme.accent
        }

        Row {
            visible: !root.expanded
            anchors.horizontalCenter: parent.horizontalCenter
            height: Services.Theme.rowHeight
            spacing: Services.Theme.tightSpacing

            Repeater {
                model: SystemTray.items
                delegate: Item {
                    id: trayIcon
                    required property var modelData

                    width: Services.Theme.traySize
                    height: Services.Theme.traySize
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        source: (trayIcon.modelData?.icon ?? "")
                        sourceSize.width: Services.Theme.traySize
                        sourceSize.height: Services.Theme.traySize
                        fillMode: Image.PreserveAspectFit
                        cache: true
                        asynchronous: true
                        visible: (trayIcon.modelData?.icon ?? "") !== ""
                    }

                    QsMenuAnchor {
                        id: menuAnchor
                        menu: trayIcon.modelData?.menu ?? null
                        anchor.item: trayIcon
                        anchor.edges: Edges.Bottom
                        anchor.gravity: Edges.Bottom
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        hoverEnabled: true
                        enabled: root.popup.visible
                        cursorShape: Qt.PointingHandCursor

                        onClicked: mouse => {
                            const item = trayIcon.modelData;
                            if (!item)
                                return;

                            try {
                                if (mouse.button === Qt.RightButton) {
                                    if (item.hasMenu && item.onlyMenu)
                                        menuAnchor.open();
                                    else
                                        item.activate();
                                } else {
                                    root.expand();
                                }
                            } catch (_) {}
                        }
                    }
                }
            }
        }

        ListView {
            id: entryList
            visible: root.expanded
            model: root.expanded ? root.entries : []
            width: root.width
            height: visible ? Math.min(root.listHeight, root.listCap) : 0
            spacing: Services.Theme.listSpacing
            clip: true
            interactive: false

            onModelChanged: {
                contentY = 0;
                positionViewAtIndex(root.selection, ListView.Contain);
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const maxY = Math.max(0, entryList.contentHeight - entryList.height);
                    entryList.contentY = Services.Theme.clamp(entryList.contentY - event.angleDelta.y, 0, maxY);
                    event.accepted = true;
                }
            }

            delegate: Item {
                id: entryRow
                required property var modelData
                required property int index

                width: root.width
                height: root.rowHeight(entryRow.modelData)

                readonly property bool isSeparator: entryRow.modelData?.isSeparator ?? false
                readonly property bool isSelected: root.expanded && index === root.selection && !isSeparator
                readonly property bool isDisabled: root.inMenu && entryRow.modelData?.enabled === false
                readonly property bool isHovered: entryArea.containsMouse && !isSeparator

                onIsSelectedChanged: {
                    if (isSelected && root.popup.visible)
                        root.popup.selectTray();
                }

                Rectangle {
                    visible: entryRow.isSeparator
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 10
                    height: 1
                    color: Services.Theme.border
                }

                Rectangle {
                    visible: !entryRow.isSeparator
                    anchors.fill: parent
                    color: entryRow.isSelected ? Services.Theme.accent : entryRow.isHovered ? Services.Theme.hoverBg : "transparent"

                    MouseArea {
                        id: entryArea
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        hoverEnabled: true
                        cursorShape: entryRow.isDisabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                        enabled: !entryRow.isDisabled && root.popup.visible

                        onContainsMouseChanged: {
                            if (containsMouse && root.selectable(entryRow.modelData))
                                root.selection = entryRow.index;
                        }

                        onClicked: mouse => {
                            if (!root.selectable(entryRow.modelData))
                                return;

                            root.selection = entryRow.index;

                            if (mouse.button === Qt.RightButton)
                                root.back();
                            else
                                root.activate();
                        }
                    }

                    Row {
                        anchors {
                            fill: parent
                            leftMargin: 8
                            rightMargin: 8
                        }
                        spacing: Services.Theme.popupSpacing

                        Image {
                            visible: !root.inMenu && (entryRow.modelData?.icon ?? "") !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            width: Services.Theme.traySize
                            height: Services.Theme.traySize
                            fillMode: Image.PreserveAspectFit
                            cache: true
                            asynchronous: true
                            source: entryRow.modelData?.icon ?? ""
                            sourceSize.width: Services.Theme.traySize
                            sourceSize.height: Services.Theme.traySize
                            opacity: entryRow.isDisabled ? 0.4 : 1
                        }

                        Text {
                            width: parent.width - (root.inMenu ? 0 : parent.spacing + Services.Theme.traySize)
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.labelFor(entryRow.modelData)
                            elide: Text.ElideRight
                            color: entryRow.isSelected ? Services.Theme.accentFg : entryRow.isDisabled ? Services.Theme.dim : Services.Theme.fg
                            opacity: entryRow.isDisabled ? 0.5 : 1
                            font.family: Services.Theme.font
                            font.pixelSize: Services.Theme.px12
                        }
                    }
                }
            }
        }

        Text {
            visible: root.expanded && root.entryCount === 0
            width: root.width
            horizontalAlignment: Text.AlignHCenter
            text: "No tray items"
            color: Services.Theme.dim
            font.family: Services.Theme.font
            font.pixelSize: Services.Theme.px12
            topPadding: 10
            bottomPadding: 10
        }
    }
}
