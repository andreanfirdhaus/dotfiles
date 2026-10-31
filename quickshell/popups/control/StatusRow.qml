import QtQuick
import Quickshell.Bluetooth
import "../../services" as Services

Item {
    id: root
    width: parent.width
    height: 18

    readonly property var wifiNet: Services.Nmcli.connected
    readonly property var connectingNet: (Services.Nmcli.networks?.find(n => n && n.ssid === Services.Nmcli.pendingSsid && !n.active) ?? null)
    readonly property bool isWired: Services.Nmcli.wiredConnected
    readonly property bool refreshing: Services.Nmcli.refreshing
    readonly property string connectivityState: Services.Nmcli.connectivityState
    readonly property bool noInternet: root.connectivityState === "none" || root.connectivityState === "limited"
    readonly property bool isPortal: root.connectivityState === "portal"
    readonly property bool isLimited: root.connectivityState === "limited"
    readonly property bool netDegraded: root.noInternet || root.isPortal
    readonly property color wifiColor: root.netDegraded ? Services.Theme.warn : Services.Theme.dim
    readonly property string wifiGlyph: {
        if (root.isWired)
            return "󰈀";
        if (!root.wifiNet)
            return "󰤯";
        if (root.netDegraded)
            return "󰤫";
        return Services.Nmcli.signalGlyph((root.wifiNet?.signal ?? 0) / 100);
    }
    readonly property string wifiText: {
        if (root.isWired) {
            if (root.isPortal)
                return "Portal";
            if (root.noInternet)
                return "No internet";
            return (Services.Nmcli.wiredDevice?.name ?? "Wired");
        }
        if (root.wifiNet) {
            const name = root.wifiNet.ssid || "Wi-Fi";
            if (root.isPortal)
                return name + " • portal";
            if (root.isLimited)
                return name + " • limited";
            if (root.noInternet)
                return "No internet";
            return name;
        }
        if (root.connectingNet)
            return (root.connectingNet.ssid || "Wi-Fi") + "…";
        if (!Services.Nmcli.wifiEnabled)
            return "Wi-Fi off";
        if (root.refreshing && !root.wifiNet)
            return "Refreshing…";
        return "Disconnected";
    }

    readonly property var btDevs: (Bluetooth.devices?.values ?? []).filter(d => d && (d.connected || d.state === BluetoothDeviceState.Connected))
    readonly property bool btEnabled: Bluetooth.defaultAdapter?.enabled ?? false
    readonly property string btGlyph: root.btDevs.length > 0 ? "󰂱" : "󰂯"
    readonly property string btText: {
        if (root.btDevs.length > 0) {
            const sorted = root.btDevs.slice().sort((a, b) => String(a.name || a.deviceName || a.address).localeCompare(String(b.name || b.deviceName || b.address)));
            const first = sorted[0].name || sorted[0].deviceName || sorted[0].address || "Bluetooth";
            return sorted.length > 1 ? first + " +" + (sorted.length - 1) : first;
        }
        if (!Bluetooth.defaultAdapter)
            return "No Bluetooth";
        if (!root.btEnabled)
            return "Bluetooth off";
        return "No devices";
    }

    readonly property bool hasBattery: Services.Power.hasBattery
    readonly property real battLevel: Services.Power.level
    readonly property bool battCharging: Services.Power.charging
    readonly property int battPct: Services.Power.pct
    readonly property string battGlyph: {
        const p = root.battLevel * 100;
        if (root.battCharging)
            return "󰂄";
        if (p >= 90)
            return "󰁹";
        if (p >= 70)
            return "󰂂";
        if (p >= 50)
            return "󰁾";
        if (p >= 30)
            return "󰁼";
        if (p >= 10)
            return "󰁺";
        return "󰂎";
    }
    readonly property string battText: root.battPct + "%"
    readonly property color battColor: {
        if (!root.battCharging) {
            if (root.battPct <= Services.Settings.criticalBatteryPct)
                return Services.Theme.danger;
            if (root.battPct <= Services.Settings.lowBatteryPct)
                return Services.Theme.warn;
        }
        return Services.Theme.dim;
    }
    readonly property int segCount: root.hasBattery ? 3 : 2

    readonly property real glyphW: 16
    readonly property real gap: 4
    readonly property real midGap: 12
    readonly property real sideMargins: 8
    readonly property real sideCap: Math.max(40, (parent.width - root.sideMargins - root.glyphW * root.segCount - root.gap * root.segCount - root.midGap * (root.segCount - 1)) / root.segCount)

    Row {
        anchors.centerIn: parent
        width: Math.min(implicitWidth, parent.width - root.sideMargins)
        spacing: root.gap
        Text {
            visible: root.hasBattery
            anchors.verticalCenter: parent.verticalCenter
            width: root.hasBattery ? root.glyphW : 0
            horizontalAlignment: Text.AlignHCenter
            text: root.battGlyph
            color: root.battColor
            font.family: Services.Theme.font
            font.pixelSize: Services.Theme.px13
        }
        Text {
            visible: root.hasBattery
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            width: root.hasBattery ? Math.min(implicitWidth, root.sideCap) : 0
            text: root.battText
            color: root.battColor
            font.family: Services.Theme.font
            font.pixelSize: Services.Theme.px11
        }
        Item {
            visible: root.hasBattery
            width: root.hasBattery ? root.midGap : 0
            height: 1
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: root.glyphW
            horizontalAlignment: Text.AlignHCenter
            text: root.wifiGlyph
            color: root.wifiColor
            font.family: Services.Theme.font
            font.pixelSize: Services.Theme.px13
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            width: Math.min(implicitWidth, root.sideCap)
            text: root.wifiText
            color: root.wifiColor
            font.family: Services.Theme.font
            font.pixelSize: Services.Theme.px11
        }
        Item {
            width: root.midGap
            height: 1
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: root.glyphW
            horizontalAlignment: Text.AlignHCenter
            text: root.btGlyph
            color: Services.Theme.dim
            font.family: Services.Theme.font
            font.pixelSize: Services.Theme.px13
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            width: Math.min(implicitWidth, root.sideCap)
            text: root.btText
            color: Services.Theme.dim
            font.family: Services.Theme.font
            font.pixelSize: Services.Theme.px11
        }
    }
}
