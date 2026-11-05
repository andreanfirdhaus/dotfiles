pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "SettingsUtil.js" as U

Singleton {
    id: settings

    property string wallpaperOverride: ""
    property var wallpapers: []
    property string wallpaperSource: ""
    property bool wallpaperScanDone: false
    property bool wallpaperNotifiedEmpty: false

    function resolveWallpaper(): void {
        if (settings.wallpaperOverride !== "") {
            settings.wallpaperNotifiedEmpty = false;
            settings.wallpaperSource = "file://" + settings.wallpaperOverride;
            return;
        }
        const first = settings.wallpapers.length > 0 ? settings.wallpapers[0] : "";
        if (first !== "") {
            settings.wallpaperNotifiedEmpty = false;
            settings.wallpaperSource = "file://" + first;
            return;
        }
        settings.wallpaperSource = "";
        if (!settings.wallpaperScanDone || settings.wallpaperNotifiedEmpty)
            return;
        settings.wallpaperNotifiedEmpty = true;
        console.warn("[wallpaper] no wallpaper found");
        Notifs.notify({app: "wallpaper", summary: "No wallpaper found", body: "Add an image to ~/dotfiles/wallpapers or ~/Pictures/Wallpapers", syncId: "wallpaper", timeout: 8000});
    }
    onWallpapersChanged: {
        if (settings.wallpaperOverride === "")
            settings.resolveWallpaper();
    }

    property real sensitivity: 0
    property real touchScroll: 0.8
    property bool naturalScroll: true

    property int dimTimeout: 150
    property int lockTimeout: 300
    property int screenOffTimeout: 330
    property int suspendTimeout: 1800

    property int lowBatteryPct: 20
    property int criticalBatteryPct: 10
    property string criticalBatteryAction: "notify"
    property string lidCloseAction: "suspend"
    property string powerProfileOnBattery: "keep"
    property string colorscheme: "vague"

    property bool loaded: false

    readonly property string settingsFile: Paths.dataPath("settings.json")
    readonly property string hypridleFile: Paths.hyprPath("hypridle.conf")

    function snapshot(): var {
        return {
            wallpaperOverride: settings.wallpaperOverride,
            sensitivity: settings.sensitivity,
            touchScroll: settings.touchScroll,
            naturalScroll: settings.naturalScroll,
            dimTimeout: settings.dimTimeout,
            lockTimeout: settings.lockTimeout,
            screenOffTimeout: settings.screenOffTimeout,
            suspendTimeout: settings.suspendTimeout,
            lowBatteryPct: settings.lowBatteryPct,
            criticalBatteryPct: settings.criticalBatteryPct,
            criticalBatteryAction: settings.criticalBatteryAction,
            lidCloseAction: settings.lidCloseAction,
            powerProfileOnBattery: settings.powerProfileOnBattery,
            colorscheme: Theme.paletteReady ? Theme.activeScheme : settings.colorscheme,
            mainMonitor: Monitors.mainMonitor,
            monitorConfigs: Monitors.monitorConfigs
        };
    }

    function applyLoaded(obj): void {
        if (!obj || typeof obj !== "object")
            return;
        settings.wallpaperOverride = U.pickStr(obj.wallpaperOverride, "");
        settings.sensitivity = U.num(obj.sensitivity, 0, -1, 1);
        settings.touchScroll = U.num(obj.touchScroll, 0.8, 0.1, 2);
        settings.naturalScroll = U.pickBool(obj.naturalScroll, true);
        settings.dimTimeout = Math.round(U.num(obj.dimTimeout, 150, 0, 600));
        settings.lockTimeout = Math.round(U.num(obj.lockTimeout, 300, 0, 3600));
        settings.screenOffTimeout = Math.round(U.num(obj.screenOffTimeout, 330, 0, 3600));
        settings.suspendTimeout = Math.round(U.num(obj.suspendTimeout, 1800, 0, 7200));
        settings.lowBatteryPct = Math.round(U.num(obj.lowBatteryPct, 20, 5, 50));
        settings.criticalBatteryPct = Math.min(Math.round(U.num(obj.criticalBatteryPct, 10, 3, 30)), settings.lowBatteryPct);
        settings.criticalBatteryAction = U.pickOpt(obj.criticalBatteryAction, "notify", ["suspend", "hibernate", "poweroff", "lock", "notify"]);
        settings.lidCloseAction = U.pickOpt(obj.lidCloseAction, "suspend", ["suspend", "lock", "ignore"]);
        settings.powerProfileOnBattery = U.pickOpt(obj.powerProfileOnBattery, "keep", ["keep", "powersaver", "balanced", "performance"]);
        settings.colorscheme = U.pickStr(obj.colorscheme, "vague");
        Monitors.applyLoaded(obj);
        settings.enforceIdleOrder();
    }

    function applyAll(): void {
        HyprBridge.hypr("input:sensitivity", String(settings.sensitivity));
        HyprBridge.hypr("input:touchpad:scroll_factor", String(settings.touchScroll));
        HyprBridge.hypr("input:touchpad:natural_scroll", settings.naturalScroll ? "true" : "false");
        settings.resolveWallpaper();
    }

    function setWallpaper(path: string): void {
        if (typeof path !== "string" || path === "")
            return;
        settings.wallpaperOverride = path;
        settings.resolveWallpaper();
        Theme.wallpaperChanged(path);
        settings.scheduleSave();
    }
    function ensureWallpaper(): void {
        if (settings.wallpaperOverride === "" && settings.wallpapers.length > 0) {
            settings.wallpaperOverride = settings.wallpapers[0];
            settings.resolveWallpaper();
            Theme.wallpaperChanged(settings.wallpaperOverride);
            settings.scheduleSave();
        }
    }
    property double lastWallScan: 0
    function refreshWallpapers(force: bool): void {
        if (wallpaperScan.running)
            return;
        if (!force && Date.now() - settings.lastWallScan < 30000)
            return;
        settings.lastWallScan = Date.now();
        wallpaperScan.running = true;
    }

    function setSensitivity(v: real): void {
        settings.sensitivity = Math.round(Math.max(-1, Math.min(1, v)) * 10) / 10;
        HyprBridge.hypr("input:sensitivity", String(settings.sensitivity));
        settings.scheduleSave();
    }
    function setTouchScroll(v: real): void {
        settings.touchScroll = Math.round(Math.max(0.1, Math.min(2, v)) * 10) / 10;
        HyprBridge.hypr("input:touchpad:scroll_factor", String(settings.touchScroll));
        settings.scheduleSave();
    }
    function setNaturalScroll(on: bool): void {
        settings.naturalScroll = on;
        HyprBridge.hypr("input:touchpad:natural_scroll", on ? "true" : "false");
        settings.scheduleSave();
    }

    function setDimTimeout(v: real): void {
        settings.dimTimeout = Math.round(Math.max(0, Math.min(600, v)));
        settings.writeIdleConf();
        settings.scheduleSave();
    }
    function setLockTimeout(v: real): void {
        settings.lockTimeout = Math.round(Math.max(0, Math.min(3600, v)));
        settings.enforceIdleOrder();
        settings.writeIdleConf();
        settings.scheduleSave();
    }
    function setScreenOffTimeout(v: real): void {
        settings.screenOffTimeout = Math.round(Math.max(0, Math.min(3600, v)));
        settings.enforceIdleOrder();
        settings.writeIdleConf();
        settings.scheduleSave();
    }
    function setSuspendTimeout(v: real): void {
        settings.suspendTimeout = Math.round(Math.max(0, Math.min(7200, v)));
        settings.enforceIdleOrder();
        settings.writeIdleConf();
        settings.scheduleSave();
    }
    function enforceIdleOrder(): void {
        if (settings.lockTimeout > 0) {
            if (settings.screenOffTimeout > 0 && settings.screenOffTimeout < settings.lockTimeout)
                settings.screenOffTimeout = settings.lockTimeout;
            if (settings.suspendTimeout > 0 && settings.suspendTimeout < settings.screenOffTimeout && settings.screenOffTimeout > 0)
                settings.suspendTimeout = settings.screenOffTimeout;
            if (settings.suspendTimeout > 0 && settings.screenOffTimeout === 0 && settings.suspendTimeout < settings.lockTimeout)
                settings.suspendTimeout = settings.lockTimeout;
        }
    }
    function setLowBatteryPct(v: real): void {
        settings.lowBatteryPct = Math.round(Math.max(5, Math.min(50, v)));
        if (settings.criticalBatteryPct > settings.lowBatteryPct)
            settings.criticalBatteryPct = settings.lowBatteryPct;
        settings.scheduleSave();
    }
    function setCriticalBatteryPct(v: real): void {
        settings.criticalBatteryPct = Math.min(Math.round(Math.max(3, Math.min(30, v))), settings.lowBatteryPct);
        settings.scheduleSave();
    }
    function setLidCloseAction(v: string): void {
        if (!["suspend", "lock", "ignore"].includes(v))
            return;
        if (settings.lidCloseAction === v)
            return;
        settings.lidCloseAction = v;
        settings.scheduleSave();
        settings.promptLidApply(v);
    }
    function promptLidApply(v: string): void {
        Notifs.notify({app: "settings", summary: "Lid close → " + v, body: "Click to install into logind (needs root). Reboot to take effect.", syncId: "lid-apply", timeout: 15000, actions: [{identifier: "default", text: "Apply", invoke: () => settings.applyLidSwitch(v)}]});
    }
    function applyLidSwitch(v: string): void {
        if (!["suspend", "lock", "ignore"].includes(v))
            return;
        lidApply.command = ["sh", "-c", 'for c in "$HOME/.local/bin/qs-power-logind" "$HOME/dotfiles/bin/qs-power-logind"; do [ -x "$c" ] && exec pkexec "$c" --install "$1"; done; exit 99', "qs", v];
        lidApply.running = true;
    }
    function setPowerProfileOnBattery(v: string): void {
        if (!["keep", "powersaver", "balanced", "performance"].includes(v))
            return;
        settings.powerProfileOnBattery = v;
        settings.scheduleSave();
    }
    property bool idleDirty: false
    function validIdleFile(file: string): bool {
        if (typeof file !== "string" || file === "" || file.length > 512)
            return false;
        if (file.includes("\n") || file.includes("\0"))
            return false;
        if (file.includes(".."))
            return false;
        const home = Quickshell.env("HOME") ?? "";
        if (home === "")
            return false;
        if (file !== home + "/.config/hypr/hypridle.conf" && !file.startsWith(home + "/.config/hypr/"))
            return false;
        return true;
    }
    function renderIdleConf(): string {
        const L = [];
        L.push("general {");
        L.push("    lock_cmd = qs ipc call bar lock");
        L.push("    before_sleep_cmd = loginctl lock-session");
        L.push("    after_sleep_cmd = hyprctl eval 'hl.dispatch(hl.dsp.dpms(\"on\"))'");
        L.push("}");
        L.push("");
        if (settings.dimTimeout > 0) {
            L.push("listener {");
            L.push("    timeout = " + settings.dimTimeout);
            L.push("    on-timeout = b=$(brightnessctl g 2>/dev/null) && [ \"${b:-0}\" -gt 2500 ] 2>/dev/null && brightnessctl -s set 3% >/dev/null 2>&1; hyprctl hyprsunset gamma 50");
            L.push("    on-resume = brightnessctl -r >/dev/null 2>&1; hyprctl hyprsunset gamma 100");
            L.push("}");
            L.push("");
            L.push("listener {");
            L.push("    timeout = " + settings.dimTimeout);
            L.push("    on-timeout = brightnessctl -sd '*:kbd_backlight' set 0 >/dev/null 2>&1 || true");
            L.push("    on-resume = brightnessctl -rd '*:kbd_backlight' >/dev/null 2>&1 || true");
            L.push("}");
            L.push("");
        }
        if (settings.lockTimeout > 0) {
            L.push("listener {");
            L.push("    timeout = " + settings.lockTimeout);
            L.push("    on-timeout = loginctl lock-session");
            L.push("}");
            L.push("");
        }
        if (settings.screenOffTimeout > 0) {
            L.push("listener {");
            L.push("    timeout = " + settings.screenOffTimeout);
            L.push("    on-timeout = loginctl lock-session; hyprctl eval 'hl.dispatch(hl.dsp.dpms(\"off\"))'");
            L.push("    on-resume = hyprctl eval 'hl.dispatch(hl.dsp.dpms(\"on\"))'");
            L.push("}");
            L.push("");
        }
        if (settings.suspendTimeout > 0) {
            L.push("listener {");
            L.push("    timeout = " + settings.suspendTimeout);
            L.push("    on-timeout = loginctl lock-session; systemctl suspend");
            L.push("}");
            L.push("");
        }
        return L.join("\n");
    }
    function flushIdleConf(): void {
        const file = settings.hypridleFile;
        if (!settings.validIdleFile(file)) {
            console.warn("quickshell: idle config target invalid, skipping write");
            return;
        }
        if (idleWriter.running) {
            settings.idleDirty = true;
            return;
        }
        idleWriter.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")"; printf "%s\\n" "$2" > "$1.tmp"; mv -f "$1.tmp" "$1"', "qs", file, settings.renderIdleConf()];
        idleWriter.running = true;
    }
    function writeIdleConf(): void {
        if (!settings.validIdleFile(settings.hypridleFile)) {
            console.warn("quickshell: idle config path invalid, skipping write");
            return;
        }
        idleDebounce.restart();
    }

    property bool saveQueued: false
    function scheduleSave(): void {
        if (!settings.loaded)
            return;
        settings.saveQueued = true;
        saveTimer.restart();
    }
    Timer {
        id: saveTimer
        interval: 800
        repeat: false
        onTriggered: {
            if (!settings.saveQueued)
                return;
            if (saver.running)
                return;
            if (settings.settingsFile === "" || Monitors.monitorsLuaFile === "") {
                console.warn("quickshell: HOME/XDG not set, skipping settings save");
                settings.saveQueued = false;
                return;
            }
            settings.saveQueued = false;
            saver.command = ["sh", "-c", 'mkdir -p "$(dirname "$2")"; printf "%s\\n" "$1" > "$2.tmp"; mv -f "$2.tmp" "$2"; mkdir -p "$(dirname "$4")"; printf "%s\\n" "$3" > "$4.tmp"; mv -f "$4.tmp" "$4"', "qs", JSON.stringify(settings.snapshot()), settings.settingsFile, Monitors.monitorsLua(), Monitors.monitorsLuaFile];
            saver.running = true;
        }
    }
    Process {
        id: saver
        onExited: exitCode => {
            if (exitCode !== 0) {
                settings.saveQueued = true;
                saveTimer.restart();
            } else if (settings.saveQueued) {
                saveTimer.restart();
            }
        }
    }
    Process {
        id: lidApply
        onExited: exitCode => {
            if (exitCode === 0)
                Notifs.notify({app: "settings", summary: "Lid action installed", body: "Reboot for logind to pick it up.", syncId: "lid-apply", timeout: 8000});
            else
                Notifs.notify({app: "settings", summary: "Lid install cancelled/failed", body: "Run qs-power-logind --apply in a terminal.", syncId: "lid-apply", timeout: 8000});
        }
    }
    Process {
        id: loader
        property bool loadDone: false
        command: ["cat", settings.settingsFile]
        stdout: StdioCollector {
            onStreamFinished: {
                if (loader.loadDone)
                    return;
                loader.loadDone = true;
                let parsed = null;
                let corrupt = false;
                try {
                    parsed = JSON.parse(text);
                } catch (_) {
                    corrupt = text.trim() !== "";
                }
                if (!corrupt && parsed !== null && (typeof parsed !== "object" || Array.isArray(parsed)))
                    corrupt = true;
                if (corrupt) {
                    console.warn("quickshell: settings.json corrupt, keeping defaults; backup at settings.json.corrupt-" + Date.now());
                    Quickshell.execDetached(["sh", "-c", 'cp "$1" "$1.corrupt-$(date +%s%3N)" 2>/dev/null', "qs", settings.settingsFile]);
                    Notifs.notify({app: "settings", summary: "Settings file corrupt, defaults kept", body: "Backup saved next to settings.json", syncId: "settings-load", timeout: 8000});
                } else {
                    settings.applyLoaded(parsed);
                }
                settings.loaded = true;
                settings.applyAll();
                settings.refreshWallpapers(true);
                Monitors.applyScannedMonitors();
            }
        }
        onExited: exitCode => {
            if (loader.loadDone)
                return;
            loader.loadDone = true;
            if (exitCode !== 0) {
                settings.loaded = true;
                settings.applyAll();
                settings.refreshWallpapers(true);
            }
        }
        Component.onCompleted: loader.running = true
    }
    Process {
        id: wallpaperScan
        command: ["sh", "-c", "for d in \"$HOME/dotfiles/wallpapers\" \"$HOME/Pictures/Wallpapers\"; do [ -d \"$d\" ] && find \"$d\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null; done | awk '!s[$0]++' | head -n 200 | { while IFS= read -r f; do k=$(stat -c '%d:%i:%s' \"$f\" 2>/dev/null) || k=\"0:0:0\"; echo \"$k $f\"; done; } | awk '!s[$1]++ {print substr($0,length($1)+2)}' | sort | head -n 100"]
        stdout: StdioCollector {
            onStreamFinished: {
                settings.wallpaperScanDone = true;
                settings.wallpapers = text.trim().split("\n").filter(s => s !== "");
                settings.ensureWallpaper();
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                settings.wallpaperScanDone = true;
                settings.wallpapers = [];
            }
        }
    }
    Timer {
        id: idleDebounce
        interval: 500
        repeat: false
        onTriggered: settings.flushIdleConf()
    }
    Process {
        id: idleWriter
        onExited: exitCode => {
            if (settings.idleDirty) {
                settings.idleDirty = false;
                settings.flushIdleConf();
                return;
            }
            if (exitCode !== 0) {
                Notifs.notify({app: "settings", summary: "Idle config write failed", body: settings.hypridleFile, timeout: 5000});
                return;
            }
            if (!idleRestarter.running)
                idleRestarter.running = true;
        }
    }
    Process {
        id: idleRestarter
        command: ["sh", "-c", "pkill -x hypridle 2>/dev/null; sleep 0.2; command -v hypridle >/dev/null || exit 0; hypridle >/dev/null 2>&1 &"]
        onExited: exitCode => {
            if (exitCode !== 0)
                Notifs.notify({app: "settings", summary: "hypridle restart failed", body: "check hypridle.conf", timeout: 5000});
        }
    }
}
