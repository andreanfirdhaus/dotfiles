import QtQuick
import "../../components"
import "../../services" as Services

Column {
    id: root
    required property var popup

    visible: popup.tab === 2
    width: parent.width
    spacing: Services.Theme.popupSpacing
    readonly property var previewMons: Services.Monitors.enabledMonitors().slice().sort((a, b) => (a.x ?? 0) - (b.x ?? 0))
    property var previewOrder: []
    property string previewAxis: ""
    readonly property real previewSpacing: 8
    readonly property real previewBoxH: 48
    readonly property real previewSlotH: root.previewBoxH + 18
    readonly property int previewAreaH: root.previewAxis === "column" ? root.previewOrder.length * root.previewSlotH + Math.max(0, root.previewOrder.length - 1) * root.previewSpacing + 16 : 78
    function boxWFor(name: string): real {
        const live = Services.Monitors.monitorLive(name);
        if (!live)
            return 64;
        const s = Services.Monitors.monitorScale(name) || 1;
        const effW = (live.width || 1920) / s;
        const effH = (live.height || 1080) / s;
        return Math.max(28, root.previewBoxH * effW / Math.max(1, effH));
    }
    function restingX(i: int): real {
        const n = root.previewOrder.length;
        if (i < 0 || i >= n)
            return 0;
        const widths = [];
        for (let k = 0; k < n; k++)
            widths.push(root.boxWFor(root.previewOrder[k]));
        if (root.previewAxis === "column")
            return (previewArea.width - widths[i]) / 2;
        let total = 0;
        for (let k = 0; k < n; k++)
            total += widths[k];
        total += root.previewSpacing * Math.max(0, n - 1);
        let x = (previewArea.width - total) / 2;
        for (let k = 0; k < i; k++)
            x += widths[k] + root.previewSpacing;
        return x;
    }
    function restingY(i: int): real {
        const n = root.previewOrder.length;
        if (i < 0 || i >= n)
            return 0;
        if (root.previewAxis !== "column")
            return (root.previewAreaH - root.previewSlotH) / 2;
        const total = n * root.previewSlotH + Math.max(0, n - 1) * root.previewSpacing;
        return (root.previewAreaH - total) / 2 + i * (root.previewSlotH + root.previewSpacing);
    }
    function syncPreviewAxis(): void {
        if (root.previewAxis !== "")
            return;
        const mons = root.previewMons;
        if (mons.length < 2) {
            root.previewAxis = "row";
            return;
        }
        let minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;
        for (const m of mons) {
            const x = m.x ?? 0, y = m.y ?? 0;
            if (x < minX)
                minX = x;
            if (x > maxX)
                maxX = x;
            if (y < minY)
                minY = y;
            if (y > maxY)
                maxY = y;
        }
        root.previewAxis = (maxY - minY) > (maxX - minX) ? "column" : "row";
    }
    function syncPreviewOrder(): void {
        root.syncPreviewAxis();
        const byAxis = root.previewAxis === "column" ? (a, b) => (a.y ?? 0) - (b.y ?? 0) : (a, b) => (a.x ?? 0) - (b.x ?? 0);
        const names = root.previewMons.slice().sort(byAxis).map(m => String(m.name ?? ""));
        const kept = root.previewOrder.filter(n => names.includes(n));
        for (const n of names) {
            if (!kept.includes(n))
                kept.push(n);
        }
        if (JSON.stringify(kept) !== JSON.stringify(root.previewOrder))
            root.previewOrder = kept;
    }
    function applyOrder(next: var, axis: string): void {
        const order = Array.isArray(next) ? next.slice() : [];
        root.previewOrder = order;
        root.previewAxis = axis;
        if (order.length === 0)
            return;
        const map = Services.Monitors.layoutCoords(order, axis);
        let changed = false;
        for (const n of order) {
            if (Services.Monitors.monitorPos(n) !== map[n]) {
                changed = true;
                break;
            }
        }
        if (!changed)
            return;
        popup.beginMonitorChange();
        Services.Monitors.setMonitorLayout(map);
    }
    function startGrab(): bool {
        popup.closeDrop();
        if (root.previewMons.length < 2)
            return false;
        const mons = Services.Monitors.enabledMonitors();
        const f = mons.find(m => m.focused === true) ?? (mons.length > 0 ? mons[0] : null);
        if (!f)
            return false;
        const name = String(f.name ?? "");
        if (root.previewOrder.indexOf(name) < 0)
            return false;
        popup.previewBaseOrder = root.previewOrder.slice();
        popup.previewBaseAxis = root.previewAxis === "" ? "row" : root.previewAxis;
        popup.previewGrabName = name;
        popup.previewGrab = true;
        return true;
    }
    function shiftGrabbed(dir: int, axis: string): bool {
        if (!popup.previewGrab)
            return false;
        const name = popup.previewGrabName;
        const i = root.previewOrder.indexOf(name);
        const j = i + dir;
        if (i < 0 || j < 0 || j >= root.previewOrder.length)
            return false;
        const next = root.previewOrder.slice();
        next.splice(i, 1);
        next.splice(j, 0, name);
        root.applyOrder(next, axis);
        return true;
    }
    onPreviewMonsChanged: root.syncPreviewOrder()
    Component.onCompleted: root.syncPreviewOrder()
    Connections {
        target: Services.Monitors
        function onMonitorConfigsChanged(): void {
            root.syncPreviewOrder();
        }
    }
    DropdownRow {
        title: "Main display"
        selected: popup.tab === 2 && popup.selectedIndex === 0
        z: popup.openMainDrop ? 100 : 0
        options: popup.mainOptions()
        current: Services.Monitors.mainMonitor
        dropEnabled: popup.enabledCount > 1
        dropOpen: popup.openMainDrop
        cursor: popup.dropCursor
        onHeaderClicked: {
            popup.selectedIndex = 0;
            popup.toggleMainDrop();
        }
        onOptionClicked: value => {
            popup.selectedIndex = 0;
            Services.Monitors.setMainMonitor(value);
            popup.closeDrop();
        }
    }
    Item {
        id: previewArea
        visible: popup.enabledCount > 1
        width: parent.width
        height: popup.enabledCount > 1 ? root.previewAreaH : 0
        Rectangle {
            id: previewBg
            anchors.fill: parent
            readonly property bool selected: popup.tab === 2 && popup.selectedIndex === 1
            readonly property bool hovered: previewMouse.containsMouse
            color: selected ? Services.Theme.activeBg : hovered ? Services.Theme.hoverBg : Services.Theme.transparent
            border.width: 1
            border.color: selected && hovered ? Services.Theme.fg : selected ? Services.Theme.accent : hovered ? Services.Theme.dim : Services.Theme.border
            MouseArea {
                id: previewMouse
                anchors.fill: parent
                hoverEnabled: true
            }
            Repeater {
                model: root.previewMons
                delegate: Item {
                    id: boxSlot
                    required property var modelData
                    readonly property string monName: String(modelData.name ?? "")
                    readonly property int orderIdx: root.previewOrder.indexOf(monName)
                    readonly property real bw: root.boxWFor(monName)
                    readonly property bool isFocused: modelData.focused === true
                    readonly property bool grabbed: popup.previewGrab && popup.previewGrabName === monName
                    readonly property bool hovered: boxMouse.containsMouse
                    width: bw
                    height: root.previewSlotH
                    x: root.restingX(orderIdx < 0 ? 0 : orderIdx)
                    y: root.restingY(orderIdx < 0 ? 0 : orderIdx)
                    z: grabbed ? 5 : 0
                    Behavior on x {
                        NumberAnimation {
                            duration: 180
                        }
                    }
                    Behavior on y {
                        NumberAnimation {
                            duration: 180
                        }
                    }
                    Column {
                        anchors.fill: parent
                        spacing: 2
                        Rectangle {
                            width: boxSlot.bw
                            height: root.previewBoxH
                            scale: boxSlot.grabbed ? 1.06 : 1
                            color: boxSlot.isFocused || boxSlot.grabbed ? Services.Theme.activeBg : Services.Theme.surface
                            border.width: 1
                            border.color: boxSlot.grabbed ? Services.Theme.accent : boxSlot.isFocused ? Services.Theme.accent : boxSlot.hovered ? Services.Theme.fg : Services.Theme.dim
                            Text {
                                anchors.centerIn: parent
                                text: boxSlot.monName.replace(/-.*$/, "")
                                color: boxSlot.isFocused || boxSlot.grabbed ? Services.Theme.fg : Services.Theme.dim
                                font.family: Services.Theme.font
                                font.pixelSize: Services.Theme.px10
                                elide: Text.ElideRight
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 120
                                }
                            }
                        }
                        Text {
                            width: boxSlot.bw
                            horizontalAlignment: Text.AlignHCenter
                            text: boxSlot.monName
                            color: Services.Theme.dim
                            font.family: Services.Theme.font
                            font.pixelSize: Services.Theme.px10
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        id: boxMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.ArrowCursor
                    }
                }
            }
        }
    }
    Text {
        visible: popup.enabledCount > 1
        width: parent.width
        height: popup.enabledCount > 1 ? popup.previewHintH : 0
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: popup.previewGrab ? "Arrows move · Enter applies · Esc cancels" : "Enter to move with keyboard"
        color: Services.Theme.dim
        font.family: Services.Theme.font
        font.pixelSize: Services.Theme.px10
    }
    Text {
        visible: popup.monCount === 0
        width: parent.width
        height: 30
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: "No monitors found. Is hyprctl reachable?"
        color: Services.Theme.dim
        font.family: Services.Theme.font
        font.pixelSize: Services.Theme.px10
    }
    Column {
        id: monColumn
        visible: popup.monCount > 0
        width: parent.width
        spacing: Services.Theme.popupSpacing
        z: popup.openMonRes !== "" ? 50 : 0
        Repeater {
            model: Services.Monitors.monitors
            delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property string monName: String(modelData.name ?? "")
                readonly property bool monOn: Services.Monitors.monitorEnabled(monName)
                width: parent.width
                height: popup.monBlockH
                color: Services.Theme.transparent
                border.width: 1
                border.color: Services.Theme.border
                z: popup.openMonRes === monName ? 100 : 0
                Column {
                    anchors.fill: parent
                    anchors.margins: popup.monCardPad
                    spacing: Services.Theme.listSpacing
                    Text {
                        width: parent.width
                        height: popup.monHeaderH
                        verticalAlignment: Text.AlignVCenter
                        text: Services.Monitors.monitorSummary(monName)
                        color: monOn ? Services.Theme.fg : Services.Theme.dim
                        font.family: Services.Theme.font
                        font.pixelSize: Services.Theme.px12
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        height: popup.monSubH
                        verticalAlignment: Text.AlignVCenter
                        text: Services.Monitors.monitorDetails(monName)
                        color: Services.Theme.dim
                        font.family: Services.Theme.font
                        font.pixelSize: Services.Theme.px10
                        elide: Text.ElideRight
                    }
                    SettingsRow {
                        selected: popup.tab === 2 && popup.selectedIndex === popup.monFirst + index * popup.monRows + 0
                        title: "Enabled"
                        value: monOn ? "On" : "Off"
                        SettingsSwitch {
                            on: monOn
                            disabled: !Services.Monitors.canDisableMonitor(monName)
                            onToggled: {
                                popup.beginMonitorChange();
                                Services.Monitors.setMonitorEnabled(monName, !Services.Monitors.monitorEnabled(monName))
                            }
                        }
                    }
                    SettingsSliderRow {
                        opacity: monOn ? 1 : 0.45
                        selected: popup.tab === 2 && popup.selectedIndex === popup.monFirst + index * popup.monRows + 1
                        title: "Scale"
                        value: "x" + Services.Monitors.monitorScale(monName).toFixed(2).replace(/\.?0+$/, "")
                        sliderMinimum: 0.5
                        sliderMaximum: 3
                        sliderValue: Services.Monitors.monitorScale(monName)
                        onSliderMoved: value => {
                            popup.beginMonitorChange();
                            Services.Monitors.setMonitorScale(monName, Math.round(value * 20) / 20)
                        }
                    }
                    DropdownRow {
                        opacity: monOn ? 1 : 0.45
                        title: "Resolution"
                        selected: popup.tab === 2 && popup.selectedIndex === popup.monFirst + index * popup.monRows + 2
                        z: popup.openMonRes === monName ? 100 : 0
                        options: Services.Monitors.monitorModes(monName)
                        current: Services.Monitors.monitorRes(monName)
                        dropOpen: popup.openMonRes === monName
                        cursor: popup.dropCursor
                        openUp: index === popup.monCount - 1
                        onHeaderClicked: {
                            popup.selectedIndex = popup.monFirst + index * popup.monRows + 2;
                            popup.toggleMonModeDrop(monName);
                        }
                        onOptionClicked: value => {
                            popup.selectedIndex = popup.monFirst + index * popup.monRows + 2;
                            popup.commitMonMode(monName, value);
                        }
                    }
                }
            }
        }
    }
    PopupButton {
        label: "Re-detect displays"
        columns: 1
        selected: popup.tab === 2 && popup.selectedIndex === popup.monLastIndex()
        onClicked: {
            popup.selectedIndex = popup.monLastIndex();
            root.syncPreviewOrder();
            Services.Monitors.refreshMonitors(true);
        }
    }
    Text {
        width: parent.width
        height: 14
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: Services.Monitors.lastApplyMsg
        color: Services.Theme.dim
        font.family: Services.Theme.font
        font.pixelSize: Services.Theme.px10
    }
}
