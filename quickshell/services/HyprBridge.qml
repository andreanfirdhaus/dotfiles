pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Singleton {
    id: bridge

    property var pending: ({})

    function hypr(key: string, value: string): void {
        bridge.queue(key, value);
    }
    function queue(key: string, value: string): void {
        const next = Object.assign({}, bridge.pending);
        next[key] = value;
        bridge.pending = next;
        debounce.restart();
    }
    function now(key: string, value: string): void {
        bridge.evalCode(bridge.luaFor(key, value));
    }
    function evalCode(code: string): void {
        if (typeof code !== "string" || code === "" || code.length > 2048)
            return;
        Quickshell.execDetached(["hyprctl", "eval", code]);
    }
    Timer {
        id: debounce
        interval: 150
        repeat: false
        onTriggered: {
            const due = bridge.pending;
            bridge.pending = {};
            for (const key of Object.keys(due))
                bridge.now(key, due[key]);
        }
    }
    function luaVal(v: string): string {
        if (v === "true" || v === "false")
            return v;
        if (v !== "" && !isNaN(Number(v)))
            return v;
        return bridge.luaStr(v);
    }
    function luaStr(v: string): string {
        const s = String(v ?? "").slice(0, 256).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\r/g, " ").replace(/\n/g, " ").replace(/[\x00-\x1F\x7F]/g, " ");
        return '"' + s + '"';
    }
    function luaFor(key: string, value: string): string {
        if (!key || typeof key !== "string" || key.length > 128)
            return "";
        if (!/^[A-Za-z0-9_:.-]+$/.test(key))
            return "";
        const parts = key.split(":");
        let inner = bridge.luaVal(value);
        for (let i = parts.length - 1; i >= 0; i--) {
            if (i === parts.length - 1)
                inner = parts[i] + " = " + inner;
            else
                inner = parts[i] + " = {" + inner + "}";
        }
        return "hl.config({" + inner + "})";
    }

    property var anchorByScreen: ({})

    function registerAnchor(name: string, win: var): void {
        if (typeof name !== "string" || name === "" || !win)
            return;
        const next = Object.assign({}, bridge.anchorByScreen);
        for (const k of Object.keys(next)) {
            if (next[k] === win && k !== name)
                delete next[k];
        }
        next[name] = win;
        bridge.anchorByScreen = next;
    }
    function syncAnchor(win: var, name: string): void {
        bridge.unregisterAnchor(win);
        if (typeof name === "string" && name !== "" && win)
            bridge.registerAnchor(name, win);
    }
    function unregisterAnchor(win: var): void {
        if (!win)
            return;
        const next = Object.assign({}, bridge.anchorByScreen);
        let changed = false;
        for (const k of Object.keys(next)) {
            if (next[k] === win) {
                delete next[k];
                changed = true;
            }
        }
        if (changed)
            bridge.anchorByScreen = next;
    }
    function anchorForScreen(name: string): var {
        if (typeof name !== "string" || name === "")
            return null;
        return bridge.anchorByScreen[name] ?? null;
    }

    function isSpecialWorkspace(ws): bool {
        if (!ws)
            return false;
        if (typeof ws === "string")
            return ws === "special" || ws.indexOf("special:") === 0;
        if (typeof ws !== "object")
            return false;
        if (typeof ws.id === "number" && ws.id < 0)
            return true;
        const n = ws.name;
        if (typeof n !== "string")
            return false;
        return n === "special" || n.indexOf("special:") === 0;
    }
    function isSpecialActive(name: string): bool {
        if (typeof name !== "string" || name === "")
            return false;
        const mon = (Hyprland.monitors?.values ?? []).find(m => m && m.name === name) ?? null;
        if (mon) {
            const sp = mon.lastIpcObject?.specialWorkspace;
            if (sp && typeof sp === "object") {
                if (typeof sp.id === "number")
                    return sp.id !== 0;
                if (typeof sp.name === "string")
                    return sp.name !== "";
            }
            if (mon.lastIpcObject)
                return false;
        }
        const wss = Hyprland.workspaces?.values ?? [];
        return wss.some(w => w && w.active === true && bridge.isSpecialWorkspace(w) && w.monitor?.name === name);
    }
    function shortSpecialName(full: string): string {
        if (typeof full !== "string" || !bridge.isSpecialWorkspace(full))
            return "";
        if (full.indexOf("special:") === 0)
            return full.slice("special:".length, "special:".length + 32);
        return full.slice(0, 32);
    }
    function specialFullName(name: string): string {
        if (!bridge.isSpecialActive(name))
            return "";
        const mon = (Hyprland.monitors?.values ?? []).find(m => m && m.name === name) ?? null;
        const raw = mon?.lastIpcObject?.specialWorkspace?.name;
        if (typeof raw === "string" && bridge.isSpecialWorkspace(raw))
            return raw;
        const wss = Hyprland.workspaces?.values ?? [];
        const ws = wss.find(w => w && w.active === true && bridge.isSpecialWorkspace(w) && w.monitor?.name === name) ?? null;
        const wn = ws?.name;
        if (typeof wn === "string" && bridge.isSpecialWorkspace(wn))
            return wn;
        return "";
    }
    function specialName(name: string): string {
        return bridge.shortSpecialName(bridge.specialFullName(name));
    }
    function hyprWorkspaceFor(toplevel): var {
        if (!toplevel)
            return null;
        const hit = (Hyprland.toplevels?.values ?? []).find(t => t && t.wayland === toplevel) ?? null;
        return hit?.workspace ?? null;
    }
    function hasWlrFullscreen(name: string): bool {
        if (typeof name !== "string" || name === "")
            return false;
        const wtls = ToplevelManager.toplevels?.values ?? [];
        return wtls.some(t => t && t.fullscreen === true && (t.screens ?? []).some(s => s && s.name === name));
    }
    function matchFullscreen(name: string, specialOnly: bool): bool {
        if (typeof name !== "string" || name === "")
            return false;
        if (specialOnly && !bridge.isSpecialActive(name))
            return false;
        if (!bridge.hasWlrFullscreen(name))
            return false;
        const htls = Hyprland.toplevels?.values ?? [];
        return htls.some(t => {
            if (!t)
                return false;
            if (!(Number(t.lastIpcObject?.fullscreen ?? 0) >= 2))
                return false;
            const ws = t.workspace;
            if (!ws || ws.active !== true)
                return false;
            const special = bridge.isSpecialWorkspace(ws) || bridge.isSpecialWorkspace(t.lastIpcObject?.workspace);
            if (specialOnly && !special)
                return false;
            if (!specialOnly && special)
                return false;
            return t.monitor?.name === name || ws.monitor?.name === name;
        });
    }
    function isFullscreen(name: string): bool {
        return bridge.matchFullscreen(name, false);
    }
    function isSpecialFullscreen(name: string): bool {
        return bridge.matchFullscreen(name, true);
    }
    function isAnyFullscreen(name: string): bool {
        return bridge.isFullscreen(name) || bridge.isSpecialFullscreen(name);
    }
    readonly property bool anyWlrFullscreen: (ToplevelManager.toplevels?.values ?? []).some(t => t && t.fullscreen === true)
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event?.name ?? "";
            const relevant = ["fullscreen", "workspace", "special", "openwindow", "closewindow", "movewindow", "focused"];
            if (relevant.some(k => n.indexOf(k) >= 0)) {
                Hyprland.refreshToplevels();
                Hyprland.refreshMonitors();
                Hyprland.refreshWorkspaces();
            }
        }
    }
    Timer {
        interval: 1500
        running: bridge.anyWlrFullscreen
        repeat: true
        onTriggered: {
            Hyprland.refreshToplevels();
            Hyprland.refreshMonitors();
        }
    }
    Component.onCompleted: {
        Hyprland.refreshToplevels();
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
    }
}
