pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
Singleton {
    id: perf
    property int cpuUsage: 0
    property real memUsed: 0
    property real memTotal: 0
    property int memPct: 0
    property real cpuTemp: -1
    property real gpuTemp: -1
    property int cpuFan: -1
    property int gpuFan: -1
    property real cpuTotal: 0
    property real cpuIdle: 0
    property bool suspended: false
    function parseStat(text: string): void {
        const line = String(text ?? "").split("\n").find(l => l.startsWith("cpu "));
        if (!line)
            return;
        const nums = line.trim().split(/\s+/);
        if (nums.length < 6 || nums[0] !== "cpu")
            return;
        let total = 0;
        for (let i = 1; i < nums.length; i++) {
            const v = parseInt(nums[i]);
            if (isNaN(v))
                return;
            total += v;
        }
        const idleUser = parseInt(nums[4]);
        const idleNice = parseInt(nums[5]);
        if (isNaN(idleUser) || isNaN(idleNice))
            return;
        const idle = idleUser + idleNice;
        if (perf.cpuTotal > 0) {
            const dTotal = total - perf.cpuTotal;
            const dIdle = idle - perf.cpuIdle;
            if (dTotal > 0)
                perf.cpuUsage = Math.round((dTotal - dIdle) / dTotal * 100);
        }
        perf.cpuTotal = total;
        perf.cpuIdle = idle;
    }
    function parseMem(text: string): void {
        const src = String(text ?? "");
        const totalMatch = src.match(/MemTotal:\s+(\d+)/);
        const availMatch = src.match(/MemAvailable:\s+(\d+)/);
        if (totalMatch && availMatch) {
            const totalKb = parseInt(totalMatch[1]);
            const availKb = parseInt(availMatch[1]);
            if (isNaN(totalKb) || isNaN(availKb))
                return;
            perf.memTotal = totalKb / 1024 / 1024;
            perf.memUsed = (totalKb - availKb) / 1024 / 1024;
            perf.memPct = totalKb > 0 ? Math.round((totalKb - availKb) / totalKb * 100) : 0;
        }
    }
    function parseSensors(text: string): void {
        const parts = String(text ?? "").trim().split(/\s+/);
        if (parts.length < 4)
            return;
        for (let i = 0; i < 4; i++) {
            if (!/^-?\d+$/.test(parts[i]))
                return;
        }
        const toTemp = v => {
            const n = parseInt(v);
            if (isNaN(n) || n < 0 || n > 200000)
                return -1;
            return n / 1000;
        };
        const toFan = v => {
            const n = parseInt(v);
            if (isNaN(n) || n < 0 || n > 100000)
                return -1;
            return n;
        };
        perf.cpuTemp = toTemp(parts[0]);
        perf.gpuTemp = toTemp(parts[1]);
        perf.cpuFan = toFan(parts[2]);
        perf.gpuFan = toFan(parts[3]);
    }
    Timer {
        id: poller
        interval: 8000
        running: !perf.suspended
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statView.reload();
            memView.reload();
            if (!sensorProc.running)
                sensorProc.running = true;
        }
    }
    FileView {
        id: statView
        path: "/proc/stat"
        printErrors: false
        onLoaded: perf.parseStat(statView.text())
        onLoadFailed: {}
    }
    FileView {
        id: memView
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: perf.parseMem(memView.text())
        onLoadFailed: {}
    }
    Process {
        id: sensorProc
        command: ["sh", "-c", "cpu=\"\"; gpu=\"\"; cf=\"\"; gf=\"\"; isnum() { case \"$1\" in \"\"|*[!0-9]*) return 1;; *) return 0;; esac; }; for d in /sys/class/hwmon/hwmon*; do [ -f \"$d/name\" ] || continue; n=$(cat \"$d/name\" 2>/dev/null); case \"$n\" in k10temp|coretemp|zenpower|k8temp|cpu_thermal) m=$(cat \"$d\"/temp*_input 2>/dev/null | sort -nr 2>/dev/null | head -1); isnum \"$m\" || m=\"\"; if [ -n \"$m\" ]; then if [ -z \"$cpu\" ] || [ \"$m\" -gt \"$cpu\" ]; then cpu=\"$m\"; fi; fi;; amdgpu|nvidia|nouveau|i915) m=$(cat \"$d\"/temp*_input 2>/dev/null | sort -nr 2>/dev/null | head -1); isnum \"$m\" || m=\"\"; if [ -n \"$m\" ]; then gpu=\"$m\"; fi;; asus*) for i in 1 2 3 4; do [ -f \"$d/fan${i}_input\" ] || continue; lbl=$(cat \"$d/fan${i}_label\" 2>/dev/null); val=$(cat \"$d/fan${i}_input\" 2>/dev/null); isnum \"$val\" || val=\"\"; [ -n \"$val\" ] || continue; case \"$lbl\" in *cpu*|*CPU*) cf=\"$val\";; *gpu*|*GPU*) gf=\"$val\";; *) if [ -z \"$cf\" ]; then cf=\"$val\"; elif [ -z \"$gf\" ]; then gf=\"$val\"; fi;; esac; done;; esac; done; if [ -z \"$cpu\" ]; then for d in /sys/class/hwmon/hwmon*; do if [ \"$(cat \"$d/name\" 2>/dev/null)\" = \"acpitz\" ]; then cpu=$(cat \"$d/temp1_input\" 2>/dev/null); break; fi; done; fi; isnum \"$cpu\" || cpu=\"-1\"; isnum \"$gpu\" || gpu=\"-1\"; isnum \"$cf\" || cf=\"-1\"; isnum \"$gf\" || gf=\"-1\"; echo \"$cpu $gpu $cf $gf\""]
        stdout: StdioCollector {
            onStreamFinished: perf.parseSensors(text)
        }
    }
}
