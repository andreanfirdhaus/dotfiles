import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import "../components"
import "../services" as Services
DeviceListBase {
    id: root
    implicitWidth: Services.Theme.popupWidth
    implicitHeight: 36 + 36 + Services.Theme.listHeight(Services.Theme.listVisible) + Services.Theme.popupSpacing * 3 + 16 + hint.implicitHeight
    targetList: btList
    listBlocked: root.pairingAddr !== ""
    property var rawDevices: Bluetooth.devices?.values ?? []
    property var _devicesCache: null
    function snapshotDevices(): void {
        root._devicesCache = root.sortedDevices;
    }
    property var sortedDevices: {
        if (!root.visible && root._devicesCache !== null)
            return root._devicesCache;
        const devs = root.rawDevices.slice();
        function rank(d) {
            if (!d)
                return 3;
            if (d.connected || d.state === BluetoothDeviceState.Connected)
                return 0;
            if (d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting)
                return 1;
            if (d.address !== "" && d.address === root.pairingAddr)
                return 1;
            if (d.paired || d.bonded)
                return 2;
            return 3;
        }
        function keyOf(d) {
            return (d.name || d.deviceName || d.address || "").toLowerCase() + "\0" + (d.address || "");
        }
        devs.sort((a, b) => rank(a) - rank(b) || (keyOf(a) < keyOf(b) ? -1 : keyOf(a) > keyOf(b) ? 1 : 0));
        return devs;
    }
    onVisibleChanged: {
        if (visible) {
            root.resetNav();
            root.autoScanOnOpen();
        } else {
            root.snapshotDevices();
        }
    }
    function autoScanOnOpen(): void {
        const adapter = Bluetooth.defaultAdapter;
        if (!adapter || !adapter.enabled || adapter.discovering)
            return;
        if (root.sortedDevices.some(d => d && (d.connected || d.state === BluetoothDeviceState.Connected)))
            return;
        adapter.discovering = true;
        scanTimeout.restart();
    }
    function activateRow(): void {
        root.activateDevice(root.selectedDevice());
    }
    function forgetRow(): void {
        root.forgetSelected();
    }
    function selectedDevice(): var {
        const devs = root.sortedDevices;
        if (btList.currentIndex < 0 || btList.currentIndex >= devs.length)
            return null;
        return devs[btList.currentIndex];
    }
    function activateDevice(device: var): void {
        if (!device)
            return;
        if (device.pairing) {
            device.cancelPair();
            return;
        }
        if (device.connected || device.state === BluetoothDeviceState.Connected) {
            device.disconnect();
            return;
        }
        const adapter = Bluetooth.defaultAdapter;
        if (adapter) {
            if (!adapter.enabled)
                adapter.enabled = true;
            adapter.pairable = true;
            if (adapter.discovering)
                adapter.discovering = false;
        }
        if (device.paired || device.bonded) {
            device.connected = !device.connected;
            return;
        }
        if (root.pairingAddr !== "")
            return;
        if (typeof device.address !== "string" || !/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/.test(device.address))
            return;
        root.pairError = "";
        root.pairingAddr = device.address;
        pairProc.command = ["sh", "-c", 'timeout 30 bluetoothctl pair "$1" && bluetoothctl trust "$1" && timeout 30 bluetoothctl connect "$1"', "sh", device.address];
        pairProc.running = true;
    }
    property string pairingAddr: ""
    property string pairError: ""
    Timer {
        id: pairErrorClear
        interval: 5000
        repeat: false
        onTriggered: root.pairError = ""
    }
    Process {
        id: pairProc
        stdout: StdioCollector {
        }
        stderr: StdioCollector {
        }
        onExited: exitCode => {
            root.pairingAddr = "";
            if (exitCode !== 0) {
                root.pairError = "Pairing failed - try again";
                pairErrorClear.restart();
            }
        }
    }
    function deviceGlyph(dev: var): string {
        const icon = String(dev?.icon || "").toLowerCase();
        const kinds = [["headset", "󰋋"], ["headphone", "󰋋"], ["audio", "󰓃"], ["phone", "󰄜"], ["mouse", "󰍽"], ["keyboard", "󰌌"], ["watch", "󰖉"], ["gaming", "󰊗"], ["joypad", "󰊗"], ["joystick", "󰊗"]];
        for (let i = 0; i < kinds.length; i++) {
            if (icon.includes(kinds[i][0]))
                return kinds[i][1];
        }
        if (dev && (dev.connected || dev.state === BluetoothDeviceState.Connected))
            return "󰂯";
        return "󰂲";
    }
    function toggleEnabled(): void {
        if (Bluetooth.defaultAdapter)
            Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
    }
    function toggleScan(): void {
        if (!Bluetooth.defaultAdapter)
            return;
        Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering;
        if (Bluetooth.defaultAdapter.discovering)
            scanTimeout.restart();
        else
            scanTimeout.stop();
    }
    Timer {
        id: scanTimeout
        interval: Services.Theme.scanTimeout
        repeat: false
        onTriggered: {
            if (Bluetooth.defaultAdapter)
                Bluetooth.defaultAdapter.discovering = false;
        }
    }
    function forgetSelected(): void {
        if (root.pairingAddr !== "")
            return;
        const dev = root.selectedDevice();
        if (dev && (dev.paired || dev.bonded) && !(dev.connected || dev.state === BluetoothDeviceState.Connected)) {
            dev.forget();
            const forgetAdapter = Bluetooth.defaultAdapter;
            if (forgetAdapter && forgetAdapter.enabled && !forgetAdapter.discovering) {
                forgetAdapter.discovering = true;
                scanTimeout.restart();
            }
        }
    }
    function statusText(dev: var): string {
        let s = "Available";
        if (dev.blocked)
            s = "Blocked";
        else if (dev.connected || dev.state === BluetoothDeviceState.Connected)
            s = "Connected";
        else if (dev.state === BluetoothDeviceState.Connecting)
            s = "Connecting…";
        else if (dev.state === BluetoothDeviceState.Disconnecting)
            s = "Disconnecting…";
        else if (dev.pairing || (dev.address !== "" && dev.address === root.pairingAddr))
            s = "Pairing… confirm on device if asked";
        else if (dev.paired || dev.bonded)
            s = "Paired";
        const tags = [];
        if (dev.batteryAvailable)
            tags.push(Math.round(dev.battery * 100) + "%");
        if (dev.address !== "")
            tags.push(dev.address);
        if (tags.length > 0)
            s += " · " + tags.join(" · ");
        return s;
    }
    function headerStatus(): string {
        if (root.pairError !== "")
            return root.pairError;
        const adapter = Bluetooth.defaultAdapter;
        if (!adapter)
            return "No Bluetooth adapter found";
        if (!adapter.enabled)
            return "Bluetooth is off";
        const devs = root.sortedDevices;
        let connected = 0;
        let paired = 0;
        for (let i = 0; i < devs.length; i++) {
            if (devs[i] && (devs[i].connected || devs[i].state === BluetoothDeviceState.Connected))
                connected++;
            else if (devs[i] && (devs[i].paired || devs[i].bonded))
                paired++;
        }
        if (connected > 0 && paired > 0)
            return connected + " connected · " + paired + " paired";
        if (connected > 0)
            return connected === 1 ? "1 connected" : connected + " connected";
        if (paired > 0)
            return paired === 1 ? "1 paired · not connected" : paired + " paired · not connected";
        if (devs.length > 0)
            return "Not connected";
        if (adapter.discovering)
            return "Scanning for devices...";
        return "No devices found";
    }
    PopupCard {
        DeviceHeader {
            statusText: root.headerStatus()
            statusColor: Services.Theme.dim
            enableLabel: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? "󰂲  Disable" : "󰂯  Enable"
            scanLabel: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering ? "󰑓  Scanning..." : "󰑐  Scan"
            onEnableClicked: root.toggleEnabled()
            onScanClicked: root.toggleScan()
        }
        Item {
            width: parent.width
            height: Services.Theme.listHeight(Services.Theme.listVisible)
            ListView {
                id: btList
                anchors.fill: parent
                clip: true
                model: root.sortedDevices
                spacing: Services.Theme.listSpacing
                onCountChanged: clampListView(btList)
                delegate: ResultRow {
                    id: row
                    required property var modelData
                    required property int index
                    selected: btList.currentIndex === index
                    highlighted: row.connected
                    rowHeight: Services.Theme.listRowHeight
                    readonly property bool connected: modelData.connected || modelData.state === BluetoothDeviceState.Connected
                    onClicked: root.activateDevice(modelData)
                    DeviceRow {
                        selected: row.selected
                        hovered: row.isHovered
                        accented: row.connected
                        glyph: root.deviceGlyph(modelData)
                        title: modelData.name || modelData.deviceName || modelData.address || "Unknown device"
                        subtitle: root.statusText(modelData)
                        reserveRight: 58
                        showForget: (modelData.paired || modelData.bonded) && !row.connected
                        onForgetRequested: root.forgetSelected()
                    }
                }
            }
            EmptyStateText {
                visible: !Bluetooth.defaultAdapter
                text: "No Bluetooth adapter"
            }
            EmptyStateText {
                visible: Bluetooth.defaultAdapter && !Bluetooth.defaultAdapter.enabled
                text: "󰂲 Bluetooth is off · press e to enable"
            }
            EmptyStateText {
                visible: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled && root.sortedDevices.length === 0
                text: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering ? "Scanning..." : "No devices · press s to scan"
            }
        }
        HintText {
            id: hint
            text: "d forget · s scan · e on/off"
        }
    }
}
