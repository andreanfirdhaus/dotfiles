import QtQuick
import Quickshell.Hyprland
import Quickshell.Wayland
import "../services" as Services

Item {
    id: root
    required property string screenName
    anchors.fill: parent
    WindowTitle {
        screenName: root.screenName
        leftItem: Services.Theme.workspacesOnLeft ? workspaces : null
    }
    Workspaces {
        id: workspaces
        screenName: root.screenName
    }

    component Workspaces: Row {
        id: root
        anchors {
            left: Services.Theme.workspacesOnLeft ? parent.left : undefined
            leftMargin: Services.Theme.barMargin
            horizontalCenter: Services.Theme.workspacesOnLeft ? undefined : parent.horizontalCenter
            verticalCenter: parent.verticalCenter
        }
        spacing: Services.Theme.listSpacing
        required property string screenName
        function isSpecialWorkspace(ws): bool {
            return ws && (ws.id < 0 || ws.name === "special" || String(ws.name).startsWith("special:"));
        }
        readonly property var pool: {
            const all = Hyprland.workspaces && Hyprland.workspaces.values ? Hyprland.workspaces.values : [];
            return all.filter(ws => {
                if (!ws || root.isSpecialWorkspace(ws))
                    return false;
                const m = ws.monitor;
                const name = (m && typeof m.name === "string" && m.name !== "") ? m.name : (typeof m === "string" ? m : "");
                return name === root.screenName;
            });
        }
        readonly property int activeId: {
            const mons = Hyprland.monitors && Hyprland.monitors.values ? Hyprland.monitors.values : [];
            for (const m of mons) {
                if (m && m.name === root.screenName && m.activeWorkspace && !root.isSpecialWorkspace(m.activeWorkspace))
                    return m.activeWorkspace.id ?? -99999;
            }
            return -99999;
        }
        readonly property var _slots: {
            const m = {};
            const ids = new Set();
            for (const ws of root.pool ?? []) {
                if (ws && typeof ws.id === "number") {
                    ids.add(ws.id);
                    m[ws.id] = ws;
                }
            }
            if (root.activeId !== -99999)
                ids.add(root.activeId);
            return {ids: [...ids].sort((a, b) => a - b), byId: m};
        }
        readonly property var slotIds: root._slots.ids
        function workspaceById(id: int): var {
            return (root.wsById ?? {})[id] ?? null;
        }
        readonly property var wsById: root._slots.byId
        function activateSlot(id: int): void {
            const target = workspaceById(id);
            if (target && typeof target.activate === "function") {
                target.activate();
                return;
            }
            if (Hyprland.usingLua)
                Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`);
            else
                Hyprland.dispatch("workspace " + String(id));
        }
        function stepSlot(dir: int): void {
            const ids = root.slotIds ?? [];
            if (ids.length === 0)
                return;
            let i = ids.indexOf(root.activeId);
            if (i < 0)
                i = dir > 0 ? -1 : 0;
            root.activateSlot(ids[(i + dir + ids.length) % ids.length]);
        }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                if (event.angleDelta.y > 0)
                    root.stepSlot(-1);
                else if (event.angleDelta.y < 0)
                    root.stepSlot(1);
                event.accepted = true;
            }
        }
        Repeater {
            model: slotIds
            delegate: Item {
                required property var modelData
                readonly property var ws: workspaceById(modelData)
                readonly property bool isFocused: ws ? !!ws.active : modelData === root.activeId
                width: 22
                height: 25
                Text {
                    anchors.centerIn: parent
                    text: ws && ws.name ? ws.name : modelData
                    color: isFocused ? Services.Theme.white : Services.Theme.dim
                    font.family: Services.Theme.font
                    font.pixelSize: Services.Theme.px12
                    font.bold: isFocused
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: activateSlot(modelData)
                }
            }
        }
    }

    component WindowTitle: Text {
        id: root
        required property string screenName
        property var leftItem: null
        anchors {
            left: root.leftItem ? root.leftItem.right : parent.left
            leftMargin: root.leftItem ? Services.Theme.titleMargin : Services.Theme.barMargin
            verticalCenter: parent.verticalCenter
        }
        readonly property string activeTitle: {
            const active = ToplevelManager.activeToplevel;
            if (!active || !active.activated)
                return "";
            if (Services.HyprBridge.isSpecialWorkspace(Services.HyprBridge.hyprWorkspaceFor(active)))
                return "";
            if ((active.screens ?? []).some(s => s && s.name === root.screenName))
                return active.title ?? "";
            return "";
        }
        readonly property string specialTag: {
            const n = Services.HyprBridge.specialName(root.screenName);
            return n !== "" ? "[" + n + "]" : "";
        }
        readonly property string specialTitle: {
            if (root.specialTag === "")
                return "";
            const ht = Hyprland.activeToplevel;
            const hw = ht?.workspace;
            if (!ht || !Services.HyprBridge.isSpecialWorkspace(hw))
                return "";
            if (hw.name !== Services.HyprBridge.specialFullName(root.screenName))
                return "";
            return ht.title ?? "";
        }
        text: {
            if (root.specialTag === "")
                return root.activeTitle;
            if (root.specialTitle === "")
                return root.specialTag;
            return root.specialTag + " " + root.specialTitle;
        }
        visible: text !== ""
        width: Math.min(implicitWidth, Services.Theme.titleMax)
        color: Services.Theme.fg
        font.family: Services.Theme.font
        font.pixelSize: Services.Theme.px12
        elide: Text.ElideRight
        maximumLineCount: 1
    }
}
