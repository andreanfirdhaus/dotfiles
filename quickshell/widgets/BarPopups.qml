import QtQuick
import Quickshell
import "../popups"
import "../services" as Services

Item {
    id: root
    required property var bar
    required property var clock

    readonly property alias bodyPanel: bodyPanel
    readonly property alias controlPanel: controlPanelPopup

    property string pendingOpen: ""
    property var pendingReturnTo: null
    property var coveredPopups: []
    readonly property var screenshotTool: root.bar?.screenshotTool ?? null
    readonly property bool pickerActive: (root.screenshotTool?.pickerActive) === true
    readonly property bool pickerCovered: (root.screenshotTool?.pickerCovered) === true
    onPickerCoveredChanged: {
        if (root.pickerCovered)
            root.parkForCover();
    }
    onPickerActiveChanged: {
        if (!root.pickerActive)
            root.restoreAfterCover();
    }
    function parkForCover(): void {
        const vis = [];
        for (const p of root.exclusivePopups) {
            if (p && p.visible) {
                vis.push(p);
                p.visible = false;
            }
        }
        root.coveredPopups = vis;
    }
    function restoreAfterCover(): void {
        const vis = root.coveredPopups ?? [];
        root.coveredPopups = [];
        if (vis.length > 0) {
            const anchor = root.bar.currentPopupAnchor();
            for (const p of vis) {
                if (!p || p.visible)
                    continue;
                if (p.anchor && anchor)
                    p.anchor.window = anchor;
                p.visible = true;
            }
        }
        root.flushPending();
    }

    readonly property var popupDefs: [
        {name: "control", item: controlPanelPopup, right: true},
        {name: "wifi", item: wifiPopup, right: true},
        {name: "bluetooth", item: bluetoothPopup, right: true},
        {name: "power", item: powerPopup, right: true},
        {name: "settings", loader: settingsLoader, right: true},
        {name: "launcher", loader: launcherLoader, right: false},
        {name: "clipboard", loader: clipboardLoader, right: false},
        {name: "emoji", loader: emojiLoader, right: false}
    ]

    function defFor(name: string): var {
        for (const d of root.popupDefs) {
            if (d.name === name)
                return d;
        }
        return null;
    }
    function itemFor(def: var): var {
        if (!def)
            return null;
        if (def.item)
            return def.item;
        return def.loader ? def.loader.item : null;
    }

    readonly property var allPopups: {
        const out = [];
        for (const d of root.popupDefs)
            out.push(root.itemFor(d));
        out.push(bodyPanel);
        return out;
    }
    readonly property var exclusivePopups: {
        const out = [];
        for (const d of root.popupDefs)
            out.push(root.itemFor(d));
        return out;
    }
    readonly property var rightPopups: {
        const out = [];
        for (const d of root.popupDefs) {
            if (d.right)
                out.push(root.itemFor(d));
        }
        out.push(bodyPanel);
        return out;
    }

    property int rightPopupBottom: {
        const top = Services.Theme.popupTopGap;
        let bottom = 0;
        for (const p of root.rightPopups) {
            if (p && p.visible && p.height > 0)
                bottom = Math.max(bottom, top + (p.extraTop ?? 0) + p.height);
        }
        return bottom;
    }
    property int rightPopupWidth: {
        let w = 0;
        for (const p of root.rightPopups) {
            if (p && p.visible)
                w = Math.max(w, p.width);
        }
        return w > 0 ? w : Services.Theme.popupWidth;
    }

    function popupByName(name: string): var {
        return root.itemFor(root.defFor(name));
    }
    function ensurePopup(name: string): var {
        const def = root.defFor(name);
        if (!def)
            return null;
        if (def.loader)
            def.loader.active = true;
        return root.itemFor(def);
    }
    function flushPending(): void {
        if (root.pendingOpen === "")
            return;
        if (root.pickerActive)
            return;
        const target = root.popupByName(root.pendingOpen);
        if (!target)
            return;
        const back = root.pendingReturnTo;
        root.pendingOpen = "";
        root.pendingReturnTo = null;
        root.openExclusive(target, back);
    }
    function closePopups(): void {
        for (const p of root.exclusivePopups) {
            if (p)
                p.visible = false;
        }
        if (root.pickerCovered)
            root.coveredPopups = (root.coveredPopups ?? []).filter(p => p && p.visible);
    }
    function closeForPicker(name: string, returnTo = null): void {
        const current = root.popupByName(name);
        if (current && current.visible)
            root.openExclusive(current, returnTo);
    }
    function togglePopup(name: string): void {
        if (root.pickerActive) {
            root.closeForPicker(name);
            return;
        }
        const target = root.ensurePopup(name);
        if (target) {
            root.pendingOpen = "";
            root.pendingReturnTo = null;
            root.openExclusive(target);
        } else {
            root.pendingOpen = name;
            root.pendingReturnTo = null;
        }
    }
    function openFromPanel(name: string): void {
        if (root.pickerActive) {
            root.closeForPicker(name, controlPanelPopup);
            return;
        }
        const target = root.ensurePopup(name);
        if (target) {
            root.pendingOpen = "";
            root.pendingReturnTo = null;
            root.openExclusive(target, controlPanelPopup);
        } else {
            root.pendingOpen = name;
            root.pendingReturnTo = controlPanelPopup;
        }
    }
    function openExclusive(target, returnTo = null): void {
        if (!target)
            return;
        const open = !target.visible;
        if (open && root.pickerActive)
            return;
        root.closePopups();
        if (open) {
            if (returnTo && returnTo.anchor && returnTo.anchor.window)
                target.anchor.window = returnTo.anchor.window;
            else
                target.anchor.window = root.bar.currentPopupAnchor();
            if (target === controlPanelPopup && bodyPanel && bodyPanel.anchor)
                bodyPanel.anchor.window = target.anchor.window;
        }
        target.returnTo = open ? returnTo : null;
        target.visible = open;
        if (open && target.useGrab !== false && typeof target.regrab === "function")
            target.regrab();
    }
    function followPopupAnchor(anchor): void {
        const pickerOpen = root.pickerActive;
        for (const p of root.allPopups) {
            if (!p || !p.anchor || p.anchor.window === anchor)
                continue;
            if (p === bodyPanel) {
                p.reanchor(anchor);
                continue;
            }
            if (!p.visible) {
                p.anchor.window = anchor;
                continue;
            }
            if (pickerOpen) {
                p.anchor.window = anchor;
                continue;
            }
            p.visible = false;
            p.anchor.window = anchor;
            p.visible = true;
            if (typeof p.regrab === "function")
                p.regrab();
        }
    }
    function revealHistory(i: int): void {
        bodyPanel.revealAt(i);
    }

    ControlPanelPopup {
        id: controlPanelPopup
        bar: root.bar
        body: bodyPanel
    }
    ControlBodyPopup {
        id: bodyPanel
        bar: root.bar
        controlPanel: controlPanelPopup
        clock: root.clock
    }
    WifiPopup {
        id: wifiPopup
        bar: root.bar
    }
    BluetoothPopup {
        id: bluetoothPopup
        bar: root.bar
    }
    PowerPopup {
        id: powerPopup
        bar: root.bar
    }
    LazyLoader {
        id: settingsLoader
        component: Component {
            SettingsPopup {
                bar: root.bar
            }
        }
        onItemChanged: root.flushPending()
    }
    LazyLoader {
        id: launcherLoader
        component: Component {
            LauncherPopup {
                bar: root.bar
            }
        }
        onItemChanged: root.flushPending()
    }
    LazyLoader {
        id: clipboardLoader
        component: Component {
            ClipboardPopup {
                bar: root.bar
            }
        }
        onItemChanged: root.flushPending()
    }
    LazyLoader {
        id: emojiLoader
        component: Component {
            EmojiPopup {
                bar: root.bar
            }
        }
        onItemChanged: root.flushPending()
    }
}
