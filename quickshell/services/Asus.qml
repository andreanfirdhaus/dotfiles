pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
Singleton {
    id: asus

    readonly property var profileOptions: ["Quiet", "Balanced", "Performance"]
    property string profile: ""
    property int chargeLimit: 100
    property bool hasAsusctl: false
    property bool hasPlatformProfile: false
    property bool hasChargeControl: false
    readonly property bool available: asus.hasAsusctl
    readonly property string profileLabel: asus.profile !== "" ? asus.profile : "unknown"

    function refresh(): void {
        if (!probe.running)
            probe.running = true;
        profileView.reload();
        chargeView.reload();
    }

    function cycleProfile(dir: int): void {
        if (!asus.hasAsusctl)
            return;
        const order = asus.profileOptions;
        let i = order.indexOf(asus.profile);
        if (i < 0)
            i = 1;
        const step = dir >= 0 ? 1 : order.length - 1;
        asus.setProfile(order[(i + step) % order.length], false);
    }

    function setProfile(name: string, quiet: bool): void {
        if (!asus.profileOptions.includes(name))
            return;
        if (!asus.hasAsusctl)
            return;
        asus.profile = name;
        Quickshell.execDetached(["asusctl", "profile", "set", name]);
        refreshSoon.restart();
    }

    function setChargeLimit(v: real): void {
        const next = Math.round(Math.max(20, Math.min(100, v)));
        if (!asus.hasAsusctl)
            return;
        if (next === asus.chargeLimit)
            return;
        asus.chargeLimit = next;
        Quickshell.execDetached(["asusctl", "battery", "limit", String(next)]);
        refreshSoon.restart();
    }

    Timer {
        id: poller
        interval: 30000
        running: asus.hasAsusctl || asus.hasPlatformProfile || asus.hasChargeControl
        repeat: true
        onTriggered: {
            if (!asus.hasAsusctl && !asus.hasPlatformProfile && !asus.hasChargeControl)
                return;
            asus.refresh();
        }
    }
    Timer {
        id: refreshSoon
        interval: 1500
        repeat: false
        onTriggered: {
            profileView.reload();
            chargeView.reload();
        }
    }
    Timer {
        id: probeRetry
        interval: 30000
        repeat: false
        onTriggered: {
            if (!asus.hasAsusctl && !probe.running)
                probe.running = true;
        }
    }
    FileView {
        id: profileView
        path: "/sys/firmware/acpi/platform_profile"
        printErrors: false
        onLoaded: {
            const cur = profileView.text().trim().toLowerCase();
            asus.hasPlatformProfile = true;
            if (cur === "quiet")
                asus.profile = "Quiet";
            else if (cur === "performance")
                asus.profile = "Performance";
            else if (cur === "balanced")
                asus.profile = "Balanced";
        }
        onLoadFailed: asus.hasPlatformProfile = false
    }
    FileView {
        id: chargeView
        path: "/sys/class/power_supply/BAT1/charge_control_end_threshold"
        printErrors: false
        onLoaded: {
            const v = parseInt(chargeView.text().trim());
            if (!isNaN(v) && v >= 20 && v <= 100) {
                asus.hasChargeControl = true;
                asus.chargeLimit = v;
            }
        }
        onLoadFailed: asus.hasChargeControl = false
    }
    Process {
        id: probe
        command: ["sh", "-c", "command -v asusctl >/dev/null"]
        onExited: exitCode => {
            asus.hasAsusctl = exitCode === 0;
            if (exitCode !== 0)
                probeRetry.restart();
        }
        Component.onCompleted: probe.running = true
    }
}
