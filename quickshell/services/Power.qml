pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Services.Notifications
Singleton {
    id: power

    readonly property var lidOptions: ["suspend", "lock", "ignore"]
    readonly property var profileOptions: ["keep", "powersaver", "balanced", "performance"]

    property var battery: (UPower.devices?.values ?? []).find(device => device && device.isLaptopBattery) ?? null
    readonly property bool hasBattery: power.battery != null
    readonly property real level: power.battery?.percentage ?? 0
    readonly property int pct: Math.round(power.level * 100)
    readonly property bool charging: power.hasBattery && (power.battery.state === UPowerDeviceState.Charging || power.battery.state === UPowerDeviceState.FullyCharged || power.battery.state === UPowerDeviceState.PendingCharge)
    readonly property bool discharging: power.hasBattery && !power.charging
    readonly property bool onBattery: UPower.onBattery

    property bool lowFired: false
    property bool criticalFired: false
    property bool actionFired: false
    property bool seenValid: false

    onPctChanged: power.evaluate()
    onChargingChanged: {
        power.evaluate();
        power.maybeArmCharger();
        power.chargerToast();
    }
    onHasBatteryChanged: {
        power.evaluate();
        if (!power.hasBattery) {
            chargerGrace.stop();
            power.chargerReady = false;
        } else {
            power.maybeArmCharger();
        }
        power.chargerToast();
    }

    property bool chargerReady: false
    property bool lastOnBattery: false
    Timer {
        id: chargerGrace
        interval: 2000
        repeat: false
        onTriggered: {
            power.chargerReady = true;
            power.lastOnBattery = UPower.onBattery;
        }
    }
    function maybeArmCharger(): void {
        if (power.hasBattery && Settings.loaded && !power.chargerReady && !chargerGrace.running)
            chargerGrace.restart();
    }
    function chargerToast(): void {
        if (!power.hasBattery)
            return;
        if (!Settings.loaded)
            return;
        if (!power.chargerReady)
            return;
        const onBatt = UPower.onBattery;
        if (onBatt === power.lastOnBattery)
            return;
        power.lastOnBattery = onBatt;
        const charging = !onBatt;
        const p = power.pct;
        if (charging)
            Notifs.notify({app: "power", summary: "Charging", body: power.chargerBody(true, p), icon: "battery-good-charging-symbolic", value: p, syncId: "charger", timeout: Theme.osdTimeout});
        else
            Notifs.notify({app: "power", summary: "On battery", body: power.chargerBody(false, p), icon: "battery-good-symbolic", value: p, syncId: "charger", timeout: Theme.osdTimeout});
    }
    function chargerBody(charging: bool, p: int): string {
        let s = p + "% · " + (charging ? "Charging" : "Discharging");
        const t = charging ? power.battery?.timeToFull ?? 0 : power.battery?.timeToEmpty ?? 0;
        if (t > 60)
            s += " · " + power.fmtDur(t) + (charging ? " to full" : " left");
        return s;
    }

    Connections {
        target: Settings
        function onLowBatteryPctChanged(): void {
            power.evaluate();
        }
        function onCriticalBatteryPctChanged(): void {
            power.evaluate();
        }
        function onCriticalBatteryActionChanged(): void {
            power.evaluate();
        }
        function onLoadedChanged(): void {
            power.evaluate();
            power.maybeArmCharger();
            power.chargerToast();
        }
    }

    Component.onCompleted: power.maybeArmCharger()

    Timer {
        id: battPoll
        interval: 60000
        running: power.hasBattery
        repeat: true
        onTriggered: {
            if (power.discharging)
                power.evaluate();
        }
    }

    property int validSamples: 0
    function evaluate(): void {
        if (!Settings.loaded)
            return;
        if (!power.hasBattery || power.charging) {
            power.lowFired = false;
            power.criticalFired = false;
            power.actionFired = false;
            power.validSamples = 0;
            return;
        }
        if (power.battery?.state === UPowerDeviceState.Unknown)
            return;
        if (!power.discharging)
            return;
        if (power.pct > 0 || power.battery?.timeToEmpty > 60) {
            power.seenValid = true;
        } else {
            power.validSamples += 1;
            if (power.validSamples >= 6)
                power.seenValid = true;
        }
        if (!power.seenValid)
            return;
        const p = power.pct;
        const low = Settings.lowBatteryPct;
        const crit = Math.min(Settings.criticalBatteryPct, low);
        if (!power.lowFired && p <= low) {
            power.lowFired = true;
            Notifs.notify({app: "power", summary: "Low battery", body: power.lowBody(p), icon: "battery-low-symbolic", value: p, syncId: "battery", timeout: 8000});
        }
        if (!power.criticalFired && p <= crit) {
            power.criticalFired = true;
            Notifs.notify({app: "power", summary: "Battery critical", body: power.criticalBody(p), icon: "battery-caution-symbolic", urgency: NotificationUrgency.Critical, syncId: "battery", timeout: 15000});
        }
        if (!power.actionFired && p <= crit) {
            power.actionFired = true;
            power.runCriticalAction();
        }
    }

    function levelWithTime(p: int): string {
        let s = p + "%";
        const t = power.battery?.timeToEmpty ?? 0;
        if (t > 60)
            s += " · ~" + power.fmtDur(t) + " left";
        return s;
    }

    function lowBody(p: int): string {
        return power.levelWithTime(p) + " · Plug in the charger";
    }

    function criticalBody(p: int): string {
        const s = power.levelWithTime(p);
        if (Settings.criticalBatteryAction === "notify")
            return s + " · Plug in immediately";
        return s + " — " + power.actionLabel(Settings.criticalBatteryAction) + " · Plug in immediately";
    }

    function actionLabel(action: string): string {
        if (action === "hibernate")
            return "Hibernating now";
        if (action === "poweroff")
            return "Shutting down now";
        if (action === "lock")
            return "Locking now";
        if (action === "notify")
            return "Plug in the charger";
        return "Suspending now";
    }

    function lock(): void {
        if (!power.hasLogind) {
            Notifs.notify({app: "power", summary: "System lock unavailable", body: "loginctl not found — in-app lock only", timeout: Theme.osdTimeout});
            return;
        }
        Quickshell.execDetached(["loginctl", "lock-session"]);
    }

    function runCriticalAction(): void {
        if (!Settings.loaded || !power.hasBattery)
            return;
        if (power.charging || !UPower.onBattery || !power.discharging)
            return;
        const crit = Math.min(Settings.criticalBatteryPct, Settings.lowBatteryPct);
        if (power.pct > crit)
            return;
        const action = Settings.criticalBatteryAction;
        if (!["notify", "lock", "suspend", "hibernate", "poweroff"].includes(action))
            return;
        if (action === "notify" || action === "lock") {
            if (action === "lock")
                power.lock();
            return;
        }
        const cmd = action === "hibernate" ? "hibernate" : action === "poweroff" ? "poweroff" : "suspend";
        if (!power.hasLogind) {
            Notifs.notify({app: "power", summary: "Power action unavailable", body: "systemctl not found", timeout: Theme.osdTimeout});
            return;
        }
        power.lock();
        Quickshell.execDetached(["systemctl", cmd, "-i"]);
    }

    function fmtDur(sec: real): string {
        const m = Math.round(sec / 60);
        if (m < 60)
            return m + "m";
        return Math.floor(m / 60) + "h " + (m % 60) + "m";
    }

    readonly property string statusLine: {
        if (!power.hasBattery)
            return "No battery";
        return power.chargerBody(power.charging, power.pct);
    }

    function levelColor(pct100: real): color {
        if (power.charging)
            return Theme.fg;
        if (pct100 <= Settings.criticalBatteryPct)
            return Theme.danger;
        if (pct100 <= Settings.lowBatteryPct)
            return Theme.warn;
        return Theme.fg;
    }

    property bool lidPresent: false
    property bool lidClosed: false
    property string lidStatePath: ""
    Timer {
        id: lidTimer
        interval: 30000
        running: power.lidStatePath !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (power.lidStatePath !== "")
                lidState.reload();
            else if (!lidDiscover.running)
                lidDiscover.running = true;
        }
    }
    FileView {
        id: lidState
        path: power.lidStatePath
        printErrors: false
        onLoaded: {
            const t = String(lidState.text() ?? "");
            if (t === "") {
                power.lidPresent = false;
                return;
            }
            power.lidPresent = true;
            power.lidClosed = t.includes("closed");
        }
        onLoadFailed: {
            power.lidPresent = false;
        }
    }
    Process {
        id: lidDiscover
        command: ["sh", "-c", "for f in /proc/acpi/button/lid/*/state; do [ -r \"$f\" ] && echo \"$f\" && exit 0; done; echo missing"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split("\n").filter(s => s !== "")[0] ?? "";
                if (p === "" || p === "missing") {
                    power.lidPresent = false;
                    power.lidStatePath = "";
                    return;
                }
                power.lidStatePath = p;
                lidState.reload();
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                power.lidPresent = false;
        }
        Component.onCompleted: lidDiscover.running = true
    }

    property bool xfceBlocking: false
    function refreshInhibitors(): void {
        inhibCheck.running = true;
    }
    Process {
        id: inhibCheck
        command: ["sh", "-c", "systemd-inhibit --list --no-legend 2>/dev/null | grep -i xfce || exit 1"]
        onExited: exitCode => {
            power.xfceBlocking = exitCode === 0;
        }
        Component.onCompleted: inhibCheck.running = true
    }

    property bool profilesAvailable: false
    property string acProfile: ""
    readonly property bool hasPerformanceProfile: PowerProfiles.hasPerformanceProfile
    readonly property string profileName: {
        if (!power.profilesAvailable)
            return "";
        const p = PowerProfiles.profile;
        if (p === PowerProfile.Performance)
            return "performance";
        if (p === PowerProfile.PowerSaver)
            return "powersaver";
        return "balanced";
    }
    function setProfileByName(name: string, quiet: bool): void {
        if (!power.profilesAvailable)
            return;
        if (name !== "powersaver" && name !== "balanced" && name !== "performance")
            return;
        if (name === "performance" && !PowerProfiles.hasPerformanceProfile) {
            return;
        }
        PowerProfiles.profile = name === "performance" ? PowerProfile.Performance : name === "powersaver" ? PowerProfile.PowerSaver : PowerProfile.Balanced;
    }
    function cycleProfile(): void {
        const order = ["balanced", "powersaver", "performance"];
        let i = order.indexOf(power.profileName);
        for (let n = 0; n < order.length; n++) {
            i = (i + 1) % order.length;
            if (order[i] !== "performance" || PowerProfiles.hasPerformanceProfile) {
                power.setProfileByName(order[i], false);
                return;
            }
        }
    }
    function cycleAutoProfile(): void {
        const opts = power.profileOptions;
        const i = opts.indexOf(Settings.powerProfileOnBattery);
        Settings.setPowerProfileOnBattery(opts[(i + 1 + opts.length) % opts.length]);
    }
    function applyAutoProfile(): void {
        if (!power.profilesAvailable)
            return;
        const pref = Settings.powerProfileOnBattery;
        if (UPower.onBattery) {
            if (pref === "keep" || pref === power.profileName)
                return;
            if (power.profileName !== "")
                power.acProfile = power.profileName;
            power.setProfileByName(pref, true);
        } else if (power.acProfile !== "") {
            const back = power.acProfile;
            power.acProfile = "";
            power.setProfileByName(back, true);
        }
    }
    Connections {
        target: UPower
        function onOnBatteryChanged(): void {
            power.applyAutoProfile();
            power.chargerToast();
        }
    }
    Process {
        id: ppProbe
        command: ["sh", "-c", "command -v powerprofilesctl >/dev/null && exit 0; test -f /usr/share/dbus-1/system-services/org.freedesktop.UPower.PowerProfiles.service"]
        onExited: exitCode => {
            power.profilesAvailable = exitCode === 0;
            if (exitCode === 0) {
                ppRetry.stop();
                power.applyAutoProfile();
            } else {
                ppRetry.restart();
            }
        }
        Component.onCompleted: ppProbe.running = true
    }
    Timer {
        id: ppRetry
        interval: 30000
        repeat: false
        onTriggered: {
            if (!ppProbe.running)
                ppProbe.running = true;
        }
    }
    property bool hasLogind: true
    Process {
        id: logindProbe
        command: ["sh", "-c", "command -v loginctl >/dev/null && command -v systemctl >/dev/null"]
        onExited: exitCode => {
            power.hasLogind = exitCode === 0;
        }
        Component.onCompleted: logindProbe.running = true
    }

    readonly property var asusProfileOptions: ["Quiet", "Balanced", "Performance"]
    property string asusProfile: ""
    property int asusChargeLimit: 100
    property bool asusHasAsusctl: false
    property bool asusHasPlatformProfile: false
    property bool asusHasChargeControl: false
    readonly property bool asusAvailable: power.asusHasAsusctl
    readonly property string asusProfileLabel: power.asusProfile !== "" ? power.asusProfile : "unknown"

    function refreshAsus(): void {
        if (!asusProbe.running)
            asusProbe.running = true;
        asusProfileView.reload();
        asusChargeView.reload();
    }

    function cycleAsusProfile(dir: int): void {
        if (!power.asusHasAsusctl)
            return;
        const order = power.asusProfileOptions;
        let i = order.indexOf(power.asusProfile);
        if (i < 0)
            i = 1;
        const step = dir >= 0 ? 1 : order.length - 1;
        power.setAsusProfile(order[(i + step) % order.length], false);
    }

    function setAsusProfile(name: string, quiet: bool): void {
        if (!power.asusProfileOptions.includes(name))
            return;
        if (!power.asusHasAsusctl)
            return;
        power.asusProfile = name;
        Quickshell.execDetached(["asusctl", "profile", "set", name]);
        asusRefreshSoon.restart();
    }

    function setAsusChargeLimit(v: real): void {
        const next = Math.round(Math.max(20, Math.min(100, v)));
        if (!power.asusHasAsusctl)
            return;
        if (next === power.asusChargeLimit)
            return;
        power.asusChargeLimit = next;
        Quickshell.execDetached(["asusctl", "battery", "limit", String(next)]);
        asusRefreshSoon.restart();
    }

    Timer {
        id: asusPoller
        interval: 30000
        running: power.asusHasAsusctl || power.asusHasPlatformProfile || power.asusHasChargeControl
        repeat: true
        onTriggered: {
            if (!power.asusHasAsusctl && !power.asusHasPlatformProfile && !power.asusHasChargeControl)
                return;
            power.refreshAsus();
        }
    }
    Timer {
        id: asusRefreshSoon
        interval: 1500
        repeat: false
        onTriggered: {
            asusProfileView.reload();
            asusChargeView.reload();
        }
    }
    Timer {
        id: asusProbeRetry
        interval: 30000
        repeat: false
        onTriggered: {
            if (!power.asusHasAsusctl && !asusProbe.running)
                asusProbe.running = true;
        }
    }
    FileView {
        id: asusProfileView
        path: "/sys/firmware/acpi/platform_profile"
        printErrors: false
        onLoaded: {
            const cur = asusProfileView.text().trim().toLowerCase();
            power.asusHasPlatformProfile = true;
            if (cur === "quiet")
                power.asusProfile = "Quiet";
            else if (cur === "performance")
                power.asusProfile = "Performance";
            else if (cur === "balanced")
                power.asusProfile = "Balanced";
        }
        onLoadFailed: power.asusHasPlatformProfile = false
    }
    FileView {
        id: asusChargeView
        path: "/sys/class/power_supply/BAT1/charge_control_end_threshold"
        printErrors: false
        onLoaded: {
            const v = parseInt(asusChargeView.text().trim());
            if (!isNaN(v) && v >= 20 && v <= 100) {
                power.asusHasChargeControl = true;
                power.asusChargeLimit = v;
            }
        }
        onLoadFailed: power.asusHasChargeControl = false
    }
    Process {
        id: asusProbe
        command: ["sh", "-c", "command -v asusctl >/dev/null"]
        onExited: exitCode => {
            power.asusHasAsusctl = exitCode === 0;
            if (exitCode !== 0)
                asusProbeRetry.restart();
        }
        Component.onCompleted: asusProbe.running = true
    }
}
