pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    function dataDir(): string {
        const xdg = Quickshell.env("XDG_DATA_HOME") ?? "";
        const home = Quickshell.env("HOME") ?? "";
        if (xdg !== "")
            return xdg + "/quickshell";
        if (home !== "")
            return home + "/.local/share/quickshell";
        return "";
    }
    function dataPath(name: string): string {
        const dir = root.dataDir();
        return dir !== "" ? dir + "/" + name : "";
    }
    function statePath(name: string): string {
        const state = Quickshell.env("XDG_STATE_HOME") ?? "";
        const home = Quickshell.env("HOME") ?? "";
        if (state !== "")
            return state + "/quickshell/" + name;
        if (home !== "")
            return home + "/.local/state/quickshell/" + name;
        return "";
    }
    function hyprPath(rel: string): string {
        const home = Quickshell.env("HOME") ?? "";
        if (home === "")
            return "";
        return home + "/.config/hypr/" + rel;
    }
}
