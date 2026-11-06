pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
Singleton {
    id: modes
    property bool caffeineActive: false
    property bool dndActive: false
    property bool loaded: false
    readonly property string modesFile: Paths.dataPath("modes.json")
    function snapshot(): string {
        return JSON.stringify({caffeine: modes.caffeineActive, dnd: modes.dndActive});
    }
    function persist(): void {
        if (!modes.loaded || modes.modesFile === "")
            return;
        writer.write(modes.modesFile, modes.snapshot(), true);
    }
    onCaffeineActiveChanged: modes.persist()
    onDndActiveChanged: modes.persist()
    function setCaffeine(on: bool): void {
        modes.caffeineActive = on;
        Notifs.notify({app: "caffeine", summary: on ? "Caffeine on" : "Caffeine off", syncId: "caffeine", timeout: Theme.osdTimeout});
    }
    function toggleCaffeine(): void {
        if (!modes.caffeineActive) {
            caffeineCheck.running = true;
            return;
        }
        modes.setCaffeine(false);
    }
    function toggleDnd(): void {
        modes.dndActive = !modes.dndActive;
        Notifs.notify({app: "dnd", summary: modes.dndActive ? "DND on" : "DND off", syncId: "dnd", timeout: Theme.osdTimeout});
    }
    property bool bluelightActive: false
    function setBluelight(on: bool): void {
        modes.bluelightActive = on;
        Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", on ? "4000" : "6000"]);
        Notifs.notify({app: "bluelight", summary: on ? "Bluelight on" : "Bluelight off", syncId: "bluelight", timeout: Theme.osdTimeout});
    }
    function toggleBluelight(): void {
        modes.setBluelight(!modes.bluelightActive);
    }
    Process {
        id: inhibitProc
        command: ["systemd-inhibit", "--what=idle:sleep", "--who=Quickshell", "--why=Caffeine mode", "sleep", "infinity"]
        running: modes.caffeineActive
        onExited: exitCode => {
            if (modes.caffeineActive && exitCode !== 0) {
                modes.caffeineActive = false;
                Notifs.notify({app: "caffeine", summary: "Caffeine failed", body: "inhibitor exited, turned off", timeout: Theme.osdTimeout});
            }
        }
    }
    Process {
        id: caffeineCheck
        command: ["sh", "-c", "command -v systemd-inhibit >/dev/null"]
        onExited: exitCode => {
            if (exitCode !== 0)
                Notifs.notify({app: "caffeine", summary: "Caffeine unavailable", body: "systemd-inhibit not found", timeout: Theme.osdTimeout});
            else if (!modes.caffeineActive)
                modes.setCaffeine(true);
        }
    }
    Process {
        id: staleLockCleanup
        command: ["sh", "-c", "pkill -f -- '[s]ystemd-inhibit.*--who=Quickshell.*sleep infinity'"]
        Component.onCompleted: staleLockCleanup.running = true
    }
    AtomicWriter {
        id: writer
    }
    Process {
        id: loader
        property bool loadDone: false
        command: ["cat", modes.modesFile]
        stdout: StdioCollector {
            onStreamFinished: {
                if (loader.loadDone)
                    return;
                loader.loadDone = true;
                try {
                    if (text.length > 16384)
                        throw "modes file too large";
                    const obj = JSON.parse(text);
                    if (obj && typeof obj === "object") {
                        if (typeof obj.caffeine === "boolean")
                            modes.caffeineActive = obj.caffeine;
                        if (typeof obj.dnd === "boolean")
                            modes.dndActive = obj.dnd;
                    }
                } catch (_) {
                    console.warn("quickshell: modes.json corrupt, keeping defaults");
                }
                modes.loaded = true;
            }
        }
        onExited: exitCode => {
            if (loader.loadDone)
                return;
            loader.loadDone = true;
            modes.loaded = true;
        }
        Component.onCompleted: {
            if (modes.modesFile !== "")
                loader.running = true;
            else
                modes.loaded = true;
        }
    }
}
