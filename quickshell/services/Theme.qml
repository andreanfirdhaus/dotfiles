pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string paletteFile: Paths.statePath("palette.json")
    property var palette: ({})
    property bool paletteReady: false
    function pick(group, key, fallback) {
        const g = root.palette ? root.palette[group] : null;
        if (g && typeof g[key] === "string" && g[key] !== "")
            return g[key];
        return fallback;
    }
    function loadPalette(text) {
        if (typeof text !== "string" || text.trim() === "")
            return;
        try {
            const parsed = JSON.parse(text);
            if (parsed && typeof parsed === "object") {
                root.palette = parsed;
                root.paletteReady = true;
            }
        } catch (e) {
            console.warn("quickshell: palette.json parse failed: " + e);
        }
    }

    property string barBg: "#d9" + root.bg.slice(1)
    property string bg: root.pick("ui", "bg", "#141415")
    property string surface: root.pick("ui", "surface", "#1c1c24")
    property string hoverBg: root.pick("ui", "overlay", "#252530")
    property string activeBg: root.pick("ui", "overlay", "#252530")
    property string border: "#26" + root.fg.slice(1)
    property string fg: root.pick("ui", "fg", "#cdcdcd")
    property string dim: root.pick("ui", "dim", "#878787")
    property string accent: root.pick("ui", "accent", "#aeaed1")
    property string accentFg: root.pick("ui", "accentFg", "#141415")
    property string white: root.pick("ui", "bright", "#ffffff")
    property string transparent: "transparent"
    property string warn: root.pick("ui", "yellow", "#f3be7c")
    property string danger: root.pick("ui", "red", "#d8647e")
    property string font: "JetBrainsMono Nerd Font Propo"

    readonly property string activeScheme: root.palette.active ?? "vague"
    readonly property string activeLabel: root.palette.label ?? "Vague"
    readonly property var schemes: root.palette.schemes ?? []
    readonly property var schemeLabels: root.schemes.map(s => s.label)
    readonly property var swatches: [
        root.pick("ui", "accent", "#aeaed1"),
        root.pick("ui", "red", "#d8647e"),
        root.pick("ui", "yellow", "#f3be7c"),
        root.pick("ui", "green", "#7fa563"),
        root.pick("ui", "blue", "#6e94b2"),
        root.pick("ui", "purple", "#bb9dbd")
    ]
    function schemeIdFor(label) {
        const hit = root.schemes.find(s => s.label === label);
        return hit ? hit.id : "";
    }
    function applyScheme(id) {
        if (typeof id !== "string" || id === "" || root.applying)
            return;
        runTheme(["set", id]);
    }
    function wallpaperChanged(path) {
        if (root.activeScheme !== "wallpaper" || root.applying)
            return;
        if (typeof path === "string" && path !== "")
            runTheme(["set", "wallpaper", "--image", path]);
    }
    property bool applying: false
    function runTheme(args) {
        root.applying = true;
        themeProc.command = ["sh", "-c", 'for c in "$HOME/.local/bin/theme" "$HOME/dotfiles/bin/theme"; do [ -x "$c" ] && exec "$c" "$@"; done; exit 99', "theme"].concat(args);
        themeProc.running = true;
    }

    FileView {
        id: paletteView
        path: root.paletteFile
        watchChanges: true
        onFileChanged: this.reload()
        onTextChanged: root.loadPalette(this.text())
        onLoaded: root.loadPalette(this.text())
    }
    Process {
        id: themeProc
        onExited: exitCode => {
            root.applying = false;
            if (exitCode !== 0) {
                Notifs.notify({app: "settings", summary: "Theme switch failed", body: "Run `theme set <preset>` in a terminal.", syncId: "theme", timeout: 8000});
            }
        }
    }

    property int px10: 10
    property int px11: 11
    property int px12: 12
    property int px13: 13
    property int px14: 14

    property int popupWidth: 340
    property int settingsWidth: 400
    property int launcherWidth: 480
    property bool launcherShowIcons: false
    property int barMargin: 6
    property int popupMargin: 6
    property int popupTopGap: 6
    property int popupPadding: 8
    property int popupSpacing: 8
    property int rowHeight: 36
    property int listRowHeight: 40
    property int toastWidth: 300
    property int osdWidth: 150
    property int osdBottomMargin: 20
    property int barHeight: 34
    property bool workspacesOnLeft: false
    property bool trayOnBar: false
    property bool powerShowShortcuts: false
    property int groupSpacing: 16
    property int tightSpacing: 8
    property int barIconPadding: 0
    property int listSpacing: 4
    property int traySize: 14
    property int titleMax: 420
    property int titleMargin: 10
    property int listVisible: 7
    property int resultMax: 40
    property int tileHeight: 40

    property int grabDelay: 100
    property int focusDelay: root.grabDelay + 50
    property int refilterDelay: 90
    property int scanTimeout: 15000
    property int toastTimeout: 5000
    property int osdTimeout: 1500
    property int lowToastTimeout: 3000
    property int criticalToastTimeout: 30000
    property int toastMax: 5
    property int historyMax: 20
    property int toastBodyMaxLines: 3
    property int historyBodyMaxLines: 4

    property real volumeMax: 1.5
    property real volumeStep: 0.02
    property int brightnessStep: 5
    property int brightnessMin: 0

    property real sigHigh: 0.75
    property real sigMed: 0.5
    property real sigLow: 0.25

    function clamp(x, a, b): real {
        return Math.max(a, Math.min(b, x));
    }
    function clamp01(x): real {
        return Math.max(0, Math.min(1, x));
    }
    function listHeight(rows): int {
        return rows * root.rowHeight + Math.max(0, rows - 1) * root.listSpacing;
    }
}
