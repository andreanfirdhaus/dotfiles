pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: nmcli

    property string iface: ""
    property bool wifiEnabled: true
    property bool scanning: false
    property var networks: []
    property var connected: null
    property string pendingSsid: ""
    property string busySsid: ""

    property var _knownNames: []
    property var _rows: []
    property bool _refreshBusy: false
    property var _connectCb: null
    property string _connectErr: ""
    property int _pollCount: 0
    property bool _scanArmed: false
    property var _downCb: null
    property string _downErr: ""
    property var _delCb: null
    property string _delErr: ""
    property var _radioCb: null
    property string _radioErr: ""
    property bool _radioWant: false
    property string _lastConnectedSsid: ""
    property bool _userDisconnect: false
    property bool _reconnectArmed: false
    property int _reconnectAttempts: 0
    readonly property int _reconnectMax: 3
    property bool refreshing: false

    property var wiredDevice: null
    property bool wiredConnected: false
    property string connectivityState: "unknown"

    function signalGlyph(s: real): string {
        const level = Math.max(0, Math.min(1, s));
        if (level >= 0.8) return "󰤨";
        if (level >= 0.5) return "󰤥";
        if (level >= 0.2) return "󰤢";
        return "󰤟";
    }

    Component.onCompleted: {
        nmcli.refresh();
    }

    function splitFields(line: string): var {
        const out = [];
        let cur = "";
        const t = String(line ?? "");
        for (let i = 0; i < t.length; i++) {
            const c = t[i];
            if (c === "\\" && i + 1 < t.length && (t[i + 1] === ":" || t[i + 1] === "\\")) {
                cur += t[i + 1];
                i++;
            } else if (c === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += c;
            }
        }
        out.push(cur);
        return out;
    }
    function parseWifiList(text: string): var {
        const rows = [];
        const lines = String(text ?? "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].replace(/\r$/, "");
            if (line.trim() === "")
                continue;
            const f = nmcli.splitFields(line);
            while (f.length < 5)
                f.push("");
            const ssid = f[0];
            const bssid = f[1];
            if (ssid === "" && bssid === "")
                continue;
            const signal = Math.max(0, Math.min(100, parseInt(f[2], 10) || 0));
            const security = f[3];
            rows.push({
                ssid: ssid,
                bssid: bssid,
                signal: signal,
                security: security,
                secure: security !== "" && security !== "--",
                active: f[4].trim() === "*",
                known: false
            });
        }
        return rows;
    }
    function parseProfiles(text: string): var {
        const names = [];
        const lines = String(text ?? "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].replace(/\r$/, "");
            if (line.trim() === "")
                continue;
            const f = nmcli.splitFields(line);
            if (f.length < 2)
                continue;
            const type = f.pop().trim();
            const name = f.join(":");
            if (type === "802-11-wireless" && name !== "")
                names.push(name);
        }
        return names;
    }
    function publish(): void {
        const known = {};
        for (let i = 0; i < nmcli._knownNames.length; i++)
            known[nmcli._knownNames[i]] = true;
        function rank(n) {
            if (!n)
                return 4;
            if (n.active)
                return 0;
            if (n.ssid !== "" && n.ssid === nmcli.pendingSsid)
                return 1;
            if (n.known)
                return 2;
            return 3;
        }
        const nets = nmcli._rows.slice();
        for (let i = 0; i < nets.length; i++)
            nets[i].known = !!known[nets[i].ssid];
        nets.sort((a, b) => {
            const r = rank(a) - rank(b);
            if (r !== 0)
                return r;
            if (b.signal !== a.signal)
                return b.signal - a.signal;
            const na = String(a.ssid ?? "").toLowerCase();
            const nb = String(b.ssid ?? "").toLowerCase();
            return na < nb ? -1 : na > nb ? 1 : 0;
        });
        nmcli.networks = nets;
        nmcli.connected = nets.find(n => n && n.active) ?? null;
    }
    function firstLine(text: string): string {
        const lines = String(text ?? "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const s = lines[i].trim().replace(/^error:\s*/i, "");
            if (s !== "")
                return s.length > 140 ? s.slice(0, 140) + "…" : s;
        }
        return "";
    }
    function mapConnectError(errText: string, exitCode: int): string {
        if (exitCode === 124)
            return "Timed out - try again";
        const t = String(errText ?? "");
        if (/secret/i.test(t))
            return "Wrong password, try again";
        if (/no network with ssid|could not be found|unknown connection|not found/i.test(t))
            return "Network gone - press s to rescan";
        const line = nmcli.firstLine(t);
        return line !== "" ? line : "Connection failed - try again";
    }
    function finishRefresh(): void {
        watchdog.stop();
        nmcli._refreshBusy = false;
        nmcli.scanning = pollTimer.running;
        nmcli.refreshing = false;
    }
    function refresh(): void {
        if (nmcli._refreshBusy)
            return;
        nmcli._refreshBusy = true;
        nmcli.refreshing = true;
        watchdog.restart();
        devProc.running = true;
    }
    function rescan(): void {
        if (nmcli.scanning) {
            pollTimer.stop();
            nmcli._pollCount = 0;
            nmcli._scanArmed = false;
            nmcli.scanning = false;
            return;
        }
        if (nmcli._refreshBusy) {
            nmcli.startPoll();
            return;
        }
        nmcli.scanning = true;
        nmcli.refreshing = true;
        nmcli._scanArmed = true;
        const cmd = ["timeout", "15", "nmcli", "device", "wifi", "rescan"];
        if (nmcli.iface !== "")
            cmd.push("ifname", nmcli.iface);
        scanProc.command = cmd;
        scanProc.running = true;
        watchdog.restart();
    }
    function startPoll(): void {
        nmcli._pollCount = 5;
        nmcli.scanning = true;
        pollTimer.restart();
    }
    function connect(ssid: string, password: string, onDone): void {
        if (nmcli.pendingSsid !== "" || !ssid)
            return;
        nmcli.pendingSsid = ssid;
        nmcli.busySsid = ssid;
        nmcli._connectCb = (typeof onDone === "function") ? onDone : null;
        nmcli._connectErr = "";
        const cmd = ["timeout", "25", "nmcli", "device", "wifi", "connect", ssid];
        if (String(password ?? "") !== "")
            cmd.push("password", String(password));
        connectProc.command = cmd;
        connectProc.running = true;
        watchdog.restart();
    }
    function disconnect(onDone): void {
        if (nmcli.iface === "") {
            if (typeof onDone === "function")
                onDone(false, "No Wi-Fi device");
            return;
        }
        nmcli._userDisconnect = true;
        nmcli._downCb = (typeof onDone === "function") ? onDone : null;
        nmcli._downErr = "";
        nmcli.busySsid = (nmcli.connected && nmcli.connected.ssid) || "";
        downProc.command = ["timeout", "10", "nmcli", "device", "disconnect", nmcli.iface];
        downProc.running = true;
        watchdog.restart();
    }
    function forget(ssid: string, onDone): void {
        if (!ssid)
            return;
        nmcli._delCb = (typeof onDone === "function") ? onDone : null;
        nmcli._delErr = "";
        delProc.command = ["timeout", "10", "nmcli", "connection", "delete", ssid];
        delProc.running = true;
        watchdog.restart();
    }
    function setEnabled(on: bool, onDone): void {
        nmcli._radioCb = (typeof onDone === "function") ? onDone : null;
        nmcli._radioErr = "";
        nmcli._radioWant = !!on;
        onoffProc.command = ["timeout", "10", "nmcli", "radio", "wifi", on ? "on" : "off"];
        onoffProc.running = true;
        watchdog.restart();
    }
    onConnectedChanged: {
        if (nmcli.connected) {
            nmcli._lastConnectedSsid = nmcli.connected.ssid;
            nmcli._userDisconnect = false;
            nmcli._reconnectArmed = false;
            nmcli._reconnectAttempts = 0;
            reconnectTimer.stop();
        } else if (nmcli._lastConnectedSsid && !nmcli._userDisconnect && nmcli.wifiEnabled && nmcli.iface && !nmcli.pendingSsid && !nmcli._reconnectArmed) {
            nmcli._reconnectArmed = true;
            reconnectTimer.start();
        }
        nmcli.startPoll();
    }
    Timer {
        id: pollTimer
        interval: 10000
        repeat: true
        onTriggered: {
            if (nmcli._pollCount <= 0) {
                pollTimer.stop();
                nmcli.scanning = false;
                return;
            }
            nmcli._pollCount--;
            nmcli.refresh();
        }
    }
    Timer {
        id: maintTimer
        interval: 30000
        repeat: true
        running: true
        onTriggered: {
            if (!nmcli._refreshBusy && nmcli.wifiEnabled && nmcli.iface !== "")
                nmcli.refresh();
        }
    }
    Timer {
        id: reconnectTimer
        interval: 5000
        repeat: false
        onTriggered: {
            nmcli._reconnectArmed = false;
            if (!nmcli._lastConnectedSsid || nmcli._userDisconnect || !nmcli.wifiEnabled || !nmcli.iface || nmcli.pendingSsid || nmcli.connected)
                return;
            const net = nmcli.networks.find(n => n && n.ssid === nmcli._lastConnectedSsid);
            if (net && net.secure) {
                nmcli._reconnectAttempts = 0;
                return;
            }
            if (nmcli._reconnectAttempts >= nmcli._reconnectMax) {
                nmcli._reconnectAttempts = 0;
                return;
            }
            nmcli._reconnectAttempts++;
            nmcli.connect(nmcli._lastConnectedSsid, "", null);
        }
    }
    Timer {
        id: watchdog
        interval: 60000
        repeat: false
        onTriggered: {
            const cb = nmcli._connectCb;
            nmcli._connectCb = null;
            if (nmcli.pendingSsid !== "" && cb)
                cb(false, "Timed out - try again");
            nmcli.pendingSsid = "";
            nmcli.busySsid = "";
            nmcli._downCb = null;
            nmcli._delCb = null;
            nmcli._radioCb = null;
            nmcli._reconnectArmed = false;
            nmcli._reconnectAttempts = 0;
            nmcli._pollCount = 0;
            pollTimer.stop();
            nmcli.finishRefresh();
        }
    }
    Process {
        id: devProc
        command: ["timeout", "10", "nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device", "status"]
        stdout: StdioCollector {
            id: devOut
        }
        onExited: {
            let iface = "";
            let wired = null;
            const lines = devOut.text.split("\n");
            for (let i = 0; i < lines.length; i++) {
                const f = nmcli.splitFields(lines[i].replace(/\r$/, ""));
                if (f.length < 3)
                    continue;
                const type = f[1].trim();
                const name = f[0].trim();
                const state = f[2].trim();
                if (name === "")
                    continue;
                if (type === "wifi" && iface === "")
                    iface = name;
                else if ((type === "ethernet" || type === "wired") && wired === null)
                    wired = { name: name, state: state, connected: state === "connected" };
            }
            nmcli.iface = iface;
            nmcli.wiredDevice = wired;
            nmcli.wiredConnected = wired !== null && wired.connected;
            radioProc.running = true;
        }
    }
    Process {
        id: radioProc
        command: ["timeout", "10", "nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            id: radioOut
        }
        onExited: {
            nmcli.wifiEnabled = radioOut.text.trim() === "enabled";
            listProc.running = true;
        }
    }
    Process {
        id: listProc
        command: ["timeout", "10", "nmcli", "-t", "-f", "SSID,BSSID,SIGNAL,SECURITY,IN-USE", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            id: listOut
        }
        onExited: {
            nmcli._rows = nmcli.parseWifiList(listOut.text);
            profProc.running = true;
        }
    }
    Process {
        id: profProc
        command: ["timeout", "10", "nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            id: profOut
        }
        onExited: {
            nmcli._knownNames = nmcli.parseProfiles(profOut.text);
            connProc.running = true;
        }
    }
    Process {
        id: connProc
        command: ["timeout", "10", "nmcli", "connectivity"]
        stdout: StdioCollector {
            id: connOut
        }
        onExited: {
            const s = String(connOut.text ?? "").trim().toLowerCase();
            if (s === "none")
                nmcli.connectivityState = "none";
            else if (s === "portal")
                nmcli.connectivityState = "portal";
            else if (s === "limited")
                nmcli.connectivityState = "limited";
            else if (s === "full")
                nmcli.connectivityState = "full";
            else
                nmcli.connectivityState = "unknown";
            nmcli.publish();
            nmcli.finishRefresh();
        }
    }
    Process {
        id: scanProc
        onExited: {
            if (!nmcli._scanArmed)
                return;
            nmcli._scanArmed = false;
            nmcli.startPoll();
            nmcli.refresh();
        }
    }
    Process {
        id: connectProc
        stdout: StdioCollector {
        }
        stderr: StdioCollector {
            id: connectErr
            onStreamFinished: nmcli._connectErr = text
        }
        onExited: exitCode => {
            const cb = nmcli._connectCb;
            nmcli._connectCb = null;
            nmcli.pendingSsid = "";
            nmcli.busySsid = "";
            let msg = "";
            if (exitCode !== 0)
                msg = nmcli.mapConnectError(nmcli._connectErr, exitCode);
            if (cb)
                cb(exitCode === 0, msg);
            nmcli.refresh();
        }
    }
    Process {
        id: downProc
        stderr: StdioCollector {
            id: downErr
            onStreamFinished: nmcli._downErr = text
        }
        onExited: exitCode => {
            const cb = nmcli._downCb;
            nmcli._downCb = null;
            nmcli.busySsid = "";
            if (cb)
                cb(exitCode === 0, exitCode === 0 ? "" : (nmcli.firstLine(nmcli._downErr) || "Disconnect failed"));
            nmcli.refresh();
        }
    }
    Process {
        id: delProc
        stderr: StdioCollector {
            id: delErr
            onStreamFinished: nmcli._delErr = text
        }
        onExited: exitCode => {
            const cb = nmcli._delCb;
            nmcli._delCb = null;
            if (cb)
                cb(exitCode === 0, exitCode === 0 ? "" : (nmcli.firstLine(nmcli._delErr) || "Forget failed"));
            nmcli.refresh();
        }
    }
    Process {
        id: onoffProc
        stderr: StdioCollector {
            id: onoffErr
            onStreamFinished: nmcli._radioErr = text
        }
        onExited: exitCode => {
            const cb = nmcli._radioCb;
            nmcli._radioCb = null;
            if (cb)
                cb(exitCode === 0, exitCode === 0 ? "" : (nmcli.firstLine(nmcli._radioErr) || "Failed to toggle Wi-Fi"));
            if (exitCode === 0 && nmcli._radioWant)
                nmcli.rescan();
            else
                nmcli.refresh();
        }
    }
}
