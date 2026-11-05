import QtQuick
import Quickshell
import "../components"
import "../services" as Services
DeviceListBase {
    id: root
    implicitWidth: Services.Theme.popupWidth
    implicitHeight: (root.inAuth ? authCol.height : wifiList.height) + 36 + 36 + Services.Theme.popupSpacing * 3 + 16 + hint.implicitHeight
    targetList: wifiList
    listBlocked: root.inAuth || root.isBusy
    Shortcut { sequence: "j"; enabled: root.visible && root.inAuth && !field.activeFocus; onActivated: root.selectedButton = (root.selectedButton + 1) % 2 }
    Shortcut { sequence: "k"; enabled: root.visible && root.inAuth && !field.activeFocus; onActivated: root.selectedButton = (root.selectedButton + 1) % 2 }
    Shortcut { sequence: "Return"; enabled: root.visible && root.inAuth && !field.activeFocus; onActivated: root.activateSelectedButton() }
    Shortcut { sequence: "Enter"; enabled: root.visible && root.inAuth && !field.activeFocus; onActivated: root.activateSelectedButton() }
    property string authSsid: ""
    property string authError: ""
    property string listError: ""
    property bool showPassword: false
    property int selectedButton: 1
    readonly property bool inAuth: root.authSsid !== ""
    readonly property bool isBusy: Services.Nmcli.busySsid !== ""
    function quitArmed(): bool {
        return !root.inAuth;
    }
    function cancelOrClose(): void {
        if (Services.Nmcli.pendingSsid !== "")
            return;
        if (root.inAuth)
            root.cancelAuth();
        else
            root.close();
    }
    onVisibleChanged: {
        if (visible) {
            root.listError = "";
            root.resetNav();
            if (!Services.Nmcli.connected && Services.Nmcli.networks.length === 0)
                Services.Nmcli.rescan();
            else
                Services.Nmcli.refresh();
        } else {
            root.cancelAuth();
        }
    }
    function activateRow(): void {
        root.activateNetwork(root.selectedNetwork());
    }
    function forgetRow(): void {
        root.forgetSelected();
    }
    function selectedNetwork(): var {
        const nets = Services.Nmcli.networks;
        if (wifiList.currentIndex < 0 || wifiList.currentIndex >= nets.length)
            return null;
        return nets[wifiList.currentIndex];
    }
    function activateNetwork(network: var): void {
        if (!network || !network.ssid)
            return;
        root.listError = "";
        if (network.ssid === Services.Nmcli.pendingSsid)
            return;
        if (network.active) {
            Services.Nmcli.disconnect(function (ok, msg) {
                if (!ok)
                    root.listError = msg;
            });
            return;
        }
        if (network.known || !network.secure) {
            root.submitConnect(network.ssid, "");
            return;
        }
        root.enterAuth(network.ssid);
    }
    function enterAuth(ssid: string): void {
        if (!ssid)
            return;
        root.authSsid = ssid;
        root.authError = "";
        root.showPassword = false;
        root.selectedButton = 1;
        root.focusTarget = field;
        field.forceActiveFocus();
    }
    function cancelAuth(): void {
        root.authSsid = "";
        root.authError = "";
        field.text = "";
        field.focus = false;
        root.focusTarget = null;
    }
    function activateSelectedButton(): void {
        if (Services.Nmcli.pendingSsid !== "")
            return;
        if (root.selectedButton === 0)
            root.cancelAuth();
        else
            root.doConnect();
    }
    function submitConnect(ssid: string, psk: string): void {
        if (!ssid || ssid === Services.Nmcli.pendingSsid)
            return;
        if (root.inAuth)
            root.authError = "Connecting…";
        Services.Nmcli.connect(ssid, psk, function (ok, msg) {
            if (ok) {
                root.authSsid = "";
                root.authError = "";
                root.listError = "";
                field.text = "";
                if (bar && typeof bar.closePopups === "function")
                    bar.closePopups();
                else
                    root.close();
            } else if (root.authSsid !== "") {
                root.authError = msg;
                field.selectAll();
                root.focusTarget = field;
                field.forceActiveFocus();
            } else {
                root.listError = msg;
            }
        });
    }
    function doConnect(): void {
        if (!root.inAuth)
            return;
        if (Services.Nmcli.pendingSsid !== "")
            return;
        const psk = String(field.text ?? "");
        if (psk === "") {
            root.authError = "Enter the Wi-Fi password";
            root.focusTarget = field;
            field.forceActiveFocus();
            return;
        }
        if (psk.length > 256)
            return;
        root.submitConnect(root.authSsid, psk);
        field.forceActiveFocus();
    }
    function forgetSelected(): void {
        const net = root.selectedNetwork();
        if (!net || !net.ssid || !net.known || net.ssid === Services.Nmcli.pendingSsid)
            return;
        Services.Nmcli.forget(net.ssid, function (ok, msg) {
            if (!ok)
                root.listError = msg;
        });
    }
    function toggleScan(): void {
        if (!Services.Nmcli.wifiEnabled)
            return;
        Services.Nmcli.rescan();
    }
    function toggleEnabled(): void {
        Services.Nmcli.setEnabled(!Services.Nmcli.wifiEnabled, function (ok, msg) {
            if (!ok)
                root.listError = msg;
        });
    }
    function headerStatus(): string {
        if (Services.Nmcli.iface === "" && Services.Nmcli.networks.length === 0)
            return "No Wi-Fi device found";
        if (!Services.Nmcli.wifiEnabled)
            return "󰤯 Wi-Fi off";
        if (Services.Nmcli.refreshing && !Services.Nmcli.connected)
            return "󰑓  Refreshing…";
        if (Services.Nmcli.connected)
            return "󰤨 " + (Services.Nmcli.connected.ssid || "Connected");
        if (Services.Nmcli.networks.length === 0)
            return Services.Nmcli.scanning ? "󰑓  Scanning…" : "󰤭 No networks found";
        return "󰤭 Not connected";
    }
    function rowSubText(net: var): string {
        if (!net)
            return "";
        if (net.active)
            return "Connected";
        if (net.ssid !== "" && net.ssid === Services.Nmcli.pendingSsid)
            return "Connecting…";
        if (net.known)
            return "Saved";
        return net.secure ? "Secured" : "Open";
    }
    PopupCard {
        DeviceHeader {
            statusText: root.headerStatus()
            statusColor: Services.Nmcli.connected ? Services.Theme.fg : Services.Theme.dim
            enableLabel: Services.Nmcli.wifiEnabled ? "󰖪  Disable" : "󰖩  Enable"
            scanLabel: Services.Nmcli.scanning ? "󰑓  Scanning..." : "󰑐  Scan"
            onEnableClicked: root.toggleEnabled()
            onScanClicked: root.toggleScan()
        }
        Item {
            visible: !root.inAuth
            width: parent.width
            height: Services.Theme.listHeight(Services.Theme.listVisible)
            ListView {
                id: wifiList
                anchors.fill: parent
                clip: true
                model: Services.Nmcli.networks
                spacing: Services.Theme.listSpacing
                onCountChanged: clampListView(wifiList)
                onModelChanged: clampListView(wifiList)
                delegate: ResultRow {
                    id: row
                    required property var modelData
                    required property int index
                    selected: wifiList.currentIndex === index
                    highlighted: row.busy || modelData.active
                    rowHeight: Services.Theme.listRowHeight
                    readonly property bool busy: modelData.ssid !== "" && modelData.ssid === Services.Nmcli.pendingSsid
                    onClicked: root.activateNetwork(modelData)
                    DeviceRow {
                        selected: row.selected
                        hovered: row.isHovered
                        accented: row.busy || modelData.active
                        glyph: Services.Nmcli.signalGlyph((Number(modelData.signal ?? 0) || 0) / 100)
                        title: modelData.ssid || "Hidden network"
                        subtitle: root.rowSubText(modelData)
                        reserveRight: 82
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            text: "󰌾"
                            color: row.selected ? Services.Theme.accentFg : row.isHovered ? Services.Theme.fg : Services.Theme.dim
                            font.family: Services.Theme.font
                            font.pixelSize: Services.Theme.px12
                            visible: !!modelData.secure
                        }
                        showForget: modelData.known && !modelData.active && !row.busy
                        onForgetRequested: root.forgetSelected()
                    }
                }
            }
            EmptyStateText {
                visible: !Services.Nmcli.iface && Services.Nmcli.networks.length === 0
                text: 'No Wi-Fi device'
            }
            EmptyStateText {
                visible: Services.Nmcli.iface !== "" && !Services.Nmcli.wifiEnabled
                text: 'Wi-Fi is off - press e to enable'
            }
            EmptyStateText {
                visible: Services.Nmcli.iface !== "" && Services.Nmcli.wifiEnabled && Services.Nmcli.networks.length === 0
                text: Services.Nmcli.scanning ? 'Scanning...' : 'No networks - press s to scan'
            }
            Text {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                visible: !root.inAuth && root.listError !== ""
                text: root.listError
                color: Services.Theme.danger
                font.family: Services.Theme.font
                font.pixelSize: Services.Theme.px12
                wrapMode: Text.WordWrap
            }
        }
        Column {
            id: authCol
            visible: root.inAuth
            width: parent.width
            spacing: Services.Theme.popupSpacing
            Text {
                width: parent.width
                text: "  " + (root.authSsid !== "" ? root.authSsid : "Wi-Fi password")
                color: Services.Theme.fg
                font.family: Services.Theme.font
                font.pixelSize: Services.Theme.px12
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: root.authError !== ""
                height: visible ? implicitHeight : 0
                text: root.authError
                color: Services.Nmcli.pendingSsid !== "" ? Services.Theme.dim : Services.Theme.danger
                font.family: Services.Theme.font
                font.pixelSize: Services.Theme.px12
                wrapMode: Text.WordWrap
            }
            Rectangle {
                width: parent.width
                height: Services.Theme.rowHeight
                color: Services.Theme.surface
                border.width: 1
                border.color: Services.Theme.border
                TextInput {
                    id: field
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 34
                    }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Services.Theme.fg
                    echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                    readOnly: Services.Nmcli.pendingSsid !== ""
                    maximumLength: 256
                    font.family: Services.Theme.font
                    font.pixelSize: Services.Theme.px12
                    Keys.onReturnPressed: root.doConnect()
                    Keys.onEnterPressed: root.doConnect()
                }
                Text {
                    anchors {
                        right: parent.right
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    width: 18
                    horizontalAlignment: Text.AlignHCenter
                    text: root.showPassword ? "󰈉" : "󰈈"
                    color: Services.Theme.dim
                    font.family: Services.Theme.font
                    font.pixelSize: Services.Theme.px13
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showPassword = !root.showPassword
                    }
                }
            }
            ConfirmRow {
                choice: root.selectedButton
                enabled: Services.Nmcli.pendingSsid === ""
                noLabel: "Cancel"
                yesLabel: "Connect"
                accentYes: true
                onPicked: index => {
                    root.selectedButton = index;
                    if (index === 0)
                        root.cancelAuth();
                    else
                        root.doConnect();
                }
            }
        }
        HintText {
            id: hint
            text: !root.inAuth ? "d forget · s scan · e on/off" : "Enter connect · Esc back"
        }
    }
}
