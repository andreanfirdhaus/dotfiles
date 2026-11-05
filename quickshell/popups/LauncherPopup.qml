import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import "../services/SettingsUtil.js" as U
import "../components/FilterUtils.js" as FilterUtils
import "../services" as Services
BasePopup {
    id: root
    anchorMode: "middle"
    focusTarget: search.input
    implicitWidth: Services.Theme.launcherWidth
    implicitHeight: 16 + Services.Theme.rowHeight + Services.Theme.popupSpacing * 2 + Services.Theme.listHeight(Services.Theme.listVisible) + hint.implicitHeight
    function quitArmed(): bool {
        return !search.hasFocus;
    }
    ListNavKeys {
        host: root
        navActive: !search.hasFocus
        step: dir => root.stepSelection(dir)
        confirm: () => root.launch()
    }
    Shortcut { sequence: "Tab"; enabled: root.visible; onActivated: root.stepSelection(1) }
    Shortcut { sequence: "Shift+Tab"; enabled: root.visible; onActivated: root.stepSelection(-1) }
    property var appsCache: null
    property var entries: []
    readonly property bool cmdMode: String(search.text ?? "").trim().startsWith(">")
    readonly property string cmdQuery: String(search.text ?? "").trim().slice(1).trim().toLowerCase().slice(0, 256)
    FilterState {
        id: filter
        onRefilterRequested: {
            if (root.visible)
                root.refilter();
        }
    }
    onVisibleChanged: {
        if (visible) {
            root.appsCache = DesktopEntries.applications?.values ?? [];
            root.refreshBins();
            root.loadHistory();
            search.text = "";
            filter.selMoved = false;
            root.refilter();
        } else {
            root.appsCache = null;
            root.entries = [];
        }
    }

    property var binaries: []
    property string binariesPath: ""
    property double binariesScanned: 0
    readonly property int binariesTtl: 300000
    onBinariesChanged: {
        if (root.visible && root.cmdMode)
            root.refilter();
    }
    function refreshBins(): void {
        if (binScanner.running) {
            binScanTimeout.restart();
            return;
        }
        const cur = Quickshell.env("PATH") ?? "";
        if (root.binaries.length > 0 && cur === root.binariesPath && Date.now() - root.binariesScanned < root.binariesTtl)
            return;
        root.binariesPath = cur;
        root.binariesScanned = Date.now();
        binScanner.running = true;
        binScanTimeout.restart();
    }
    Process {
        id: binScanner
        command: ["sh", "-c", "printf '%s' \"$PATH\" | tr ':' '\\n' | while IFS= read -r d; do [ -n \"$d\" ] && [ -d \"$d\" ] && find \"$d\" -maxdepth 1 \\( -type f -o -type l \\) -executable -printf '%f\\n' 2>/dev/null; done | sort -u | head -n 10000"]
        stdout: StdioCollector {
            onStreamFinished: {
                binScanTimeout.stop();
                const names = text.trim().split("\n").filter(n => n !== "" && n.length < 256);
                root.binaries = names.map(n => ({name: n, ln: n.toLowerCase()}));
            }
        }
        onExited: exitCode => {
            binScanTimeout.stop();
            if (exitCode !== 0 && root.binaries.length === 0)
                root.binariesScanned = 0;
        }
    }
    Timer {
        id: binScanTimeout
        interval: 15000
        repeat: false
        onTriggered: {
            if (binScanner.running)
                binScanner.running = false;
        }
    }

    property var historyCounts: ({})
    property var historyPending: []
    property var historyRetryQueue: []
    property var historyActiveBatch: []
    property bool historyLoaded: false
    property bool historyLoading: false
    property bool historyRewriting: false
    property bool historyRewriteQueued: false
    readonly property string historyFile: U.dataPath("launch-history.jsonl")
    onHistoryLoadedChanged: {
        if (root.visible)
            root.refilter();
    }
    function lookup(key: string): var {
        return root.historyCounts[key] ?? {c: 0, t: 0};
    }
    function countFor(key: string): int {
        return root.lookup(key).c;
    }
    function lastFor(key: string): real {
        return root.lookup(key).t;
    }
    function recentCmds(prefix: string, limit: int): var {
        const q = String(prefix ?? "").toLowerCase();
        const out = [];
        for (const k of Object.keys(root.historyCounts)) {
            if (!k.startsWith("cmd:"))
                continue;
            const cmd = k.slice(4);
            if (cmd === "")
                continue;
            const lc = cmd.toLowerCase();
            if (q !== "" && !lc.startsWith(q) && !lc.includes(q))
                continue;
            const e = root.historyCounts[k];
            out.push({name: cmd, key: k, use: e.c, last: e.t});
        }
        out.sort((a, b) => (b.last - a.last) || (b.use - a.use));
        return out.slice(0, Math.max(0, limit));
    }
    function record(key: string): void {
        if (typeof key !== "string" || key === "" || key.length > 512)
            return;
        const e = root.lookup(key);
        e.c += 1;
        e.t = Date.now();
        root.historyCounts[key] = e;
        root.capKeys();
        const line = JSON.stringify({k: key, t: e.t});
        if (root.historyLoaded)
            root.appendLines([line]);
        else
            root.historyPending.push(line);
    }
    function loadHistory(): void {
        if (root.historyLoaded || root.historyLoading)
            return;
        if (root.historyFile === "")
            return;
        root.historyLoading = true;
        historyReader.running = true;
    }
    function capKeys(): void {
        const keys = Object.keys(root.historyCounts);
        if (keys.length <= 200)
            return;
        keys.sort((a, b) => {
            const ea = root.historyCounts[a];
            const eb = root.historyCounts[b];
            return (eb.c - ea.c) || (eb.t - ea.t);
        });
        for (const k of keys.slice(200))
            delete root.historyCounts[k];
    }
    function writeCommand(lines: var, append: bool): var {
        return ["sh", "-c", 'mkdir -p "$(dirname "$2")"; printf "%s\\n" "$1" ' + (append ? ">>" : ">") + ' "$2"', "qs", lines.join("\n"), root.historyFile];
    }
    function appendLines(lines: var): void {
        for (const l of lines)
            root.historyRetryQueue.push(l);
        root.pumpWrites();
    }
    function pumpWrites(): void {
        if (root.historyFile === "")
            return;
        if (historyWriter.running || root.historyRewriting || root.historyRetryQueue.length === 0)
            return;
        if (root.historyRewriteQueued) {
            root.historyRewriteQueued = false;
            root.writeFull();
            return;
        }
        root.historyActiveBatch = root.historyRetryQueue.slice(0, 50);
        root.historyRetryQueue = root.historyRetryQueue.slice(50);
        historyWriter.command = root.writeCommand(root.historyActiveBatch, true);
        historyWriter.running = true;
    }
    function writeFull(): void {
        if (root.historyFile === "")
            return;
        if (historyWriter.running || root.historyRewriting) {
            root.historyRewriteQueued = true;
            return;
        }
        const lines = [];
        for (const k of Object.keys(root.historyCounts)) {
            const e = root.historyCounts[k];
            lines.push(JSON.stringify({k: k, c: e.c, t: e.t}));
        }
        root.historyRetryQueue = [];
        root.historyActiveBatch = [];
        root.historyRewriting = true;
        historyWriter.command = root.writeCommand(lines, false);
        historyWriter.running = true;
    }
    Process {
        id: historyReader
        command: ["sh", "-c", 'tail -n 2000 "$1" 2>/dev/null || cat "$1" 2>/dev/null', "qs", root.historyFile]
        stdout: StdioCollector {
            onStreamFinished: {
                const counts = root.historyCounts;
                let lines = 0;
                for (const line of text.split("\n")) {
                    if (line.trim() === "")
                        continue;
                    lines += 1;
                    try {
                        if (line.length > 2048)
                            continue;
                        const r = JSON.parse(line);
                        if (typeof r.k !== "string" || r.k === "" || r.k.length > 512)
                            continue;
                        const e = counts[r.k] ?? {c: 0, t: 0};
                        const dc = (typeof r.c === "number" && isFinite(r.c)) ? Math.max(0, Math.min(100000, r.c)) : 1;
                        e.c += dc;
                        if (typeof r.t === "number" && isFinite(r.t) && r.t > e.t)
                            e.t = Math.min(r.t, Date.now());
                        counts[r.k] = e;
                    } catch (_) {}
                }
                root.capKeys();
                if (lines > 1000) {
                    root.historyPending = [];
                    root.writeFull();
                } else if (root.historyPending.length > 0) {
                    root.appendLines(root.historyPending);
                    root.historyPending = [];
                }
                root.historyLoading = false;
                root.historyLoaded = true;
            }
        }
        onExited: exitCode => {
            if (root.historyLoading && !root.historyLoaded) {
                root.historyLoading = false;
                root.historyLoaded = true;
            }
        }
    }
    Process {
        id: historyWriter
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.historyRetryQueue = root.historyActiveBatch.concat(root.historyRetryQueue);
                root.historyActiveBatch = [];
                root.historyRewriting = false;
                historyRetryTimer.restart();
                return;
            }
            root.historyActiveBatch = [];
            root.historyRewriting = false;
            if (root.historyRewriteQueued) {
                root.historyRewriteQueued = false;
                root.writeFull();
                return;
            }
            root.pumpWrites();
        }
    }
    Timer {
        id: historyRetryTimer
        interval: 5000
        repeat: false
        onTriggered: root.pumpWrites()
    }
    function refreshApps(): void {
        if (root.visible && !root.cmdMode) {
            root.appsCache = DesktopEntries.applications?.values ?? [];
            root.refilter();
        }
    }
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            refreshApps();
        }
        function onObjectInsertedPost() {
            refreshApps();
        }
    }
    function stepSelection(dir: int): void {
        filter.flush();
        stepListView(resultList, dir);
        filter.selMoved = true;
    }
    function refilter(): void {
        if (root.cmdMode)
            root.refilterRun(root.cmdQuery.slice(0, 256));
        else
            root.refilterApps(String(search.text ?? "").toLowerCase().trim().slice(0, 256));
    }
    function hlQuery(): string {
        return root.cmdMode ? root.cmdQuery : String(search.text ?? "").toLowerCase().trim();
    }
    function entryKey(e): string {
        if (!e)
            return "";
        if (typeof e.key === "string" && e.key !== "")
            return e.key;
        if (e.entry)
            return "app:" + (e.entry.id ?? e.name);
        return "bin:" + e.name;
    }
    readonly property var systemActions: [
        {name: "Wi-Fi", popup: "wifi", keywords: ["wifi", "wireless", "network", "wlan"]},
        {name: "Bluetooth", popup: "bluetooth", keywords: ["bluetooth", "bt", "wireless"]}
    ]
    function matchSystemActions(q: string, out: var): void {
        const empty = q === "";
        for (const def of root.systemActions) {
            const name = String(def.name ?? "").toLowerCase();
            let best = 4;
            if (empty) {
                best = 1;
            } else {
                best = FilterUtils.matchScoreLn(name, q);
                for (const h of def.keywords ?? []) {
                    best = Math.min(best, FilterUtils.matchScoreLn(String(h ?? "").toLowerCase(), q));
                    if (best === 0)
                        break;
                }
            }
            if (best < 4) {
                const key = "popup:" + def.popup;
                out.push({name: def.name, ln: name, key: key, popup: def.popup, icon: "", score: best, use: root.countFor(key), last: root.lastFor(key)});
            }
        }
    }
    function sortScored(out: var): void {
        out.sort((a, b) => (a.score - b.score) || ((b.use ?? 0) - (a.use ?? 0)) || ((b.last ?? 0) - (a.last ?? 0)) || ((a.ln ?? "") < (b.ln ?? "") ? -1 : (a.ln ?? "") > (b.ln ?? "") ? 1 : 0));
    }
    function refilterApps(q: string): void {
        const apps = root.appsCache ?? [];
        const out = [];
        const empty = q === "";
        for (const app of apps) {
            const name = app.name ?? app.genericName ?? "";
            if (name === "")
                continue;
            let best = 4;
            if (empty) {
                best = 1;
            } else {
                best = FilterUtils.matchScoreLn(String(app.name ?? "").toLowerCase(), q);
                if (best !== 0)
                    best = Math.min(best, FilterUtils.matchScoreLn(String(app.genericName ?? "").toLowerCase(), q));
                if (best !== 0)
                    best = Math.min(best, FilterUtils.matchScoreLn(String(app.comment ?? "").toLowerCase(), q));
                if (best !== 0) {
                    const kws = app.keywords ?? [];
                    for (const h of kws) {
                        best = Math.min(best, FilterUtils.matchScoreLn(String(h ?? "").toLowerCase(), q));
                        if (best === 0)
                            break;
                    }
                }
            }
            if (best < 4) {
                const appKey = "app:" + (app.id ?? name);
                out.push({name: name, ln: String(name ?? "").toLowerCase(), key: appKey, entry: app, icon: app.icon ?? "", score: best, use: root.countFor(appKey), last: root.lastFor(appKey)});
            }
        }
        root.matchSystemActions(q, out);
        root.sortScored(out);
        root.applyResults(out.slice(0, Services.Theme.resultMax));
    }
    function refilterRun(q: string): void {
        const out = [];
        const seen = new Set();
        for (const b of root.binaries ?? []) {
            const score = FilterUtils.matchScoreLn(b.ln ?? "", q);
            if (score < 4) {
                seen.add(b.name);
                out.push({name: b.name, ln: b.ln ?? "", key: "bin:" + b.name, icon: "", score: score, use: root.countFor("bin:" + b.name), last: root.lastFor("bin:" + b.name)});
            }
        }
        for (const c of root.recentCmds(root.cmdQuery, 5)) {
            if (!seen.has(c.name)) {
                seen.add(c.name);
                out.push({name: c.name, ln: c.name.toLowerCase(), key: c.key, icon: "", score: 1, use: c.use, last: c.last, isCmd: true});
            }
        }
        root.sortScored(out);
        root.applyResults(out.slice(0, Services.Theme.resultMax));
    }
    function applyResults(out: var): void {
        const idx = filter.keptIndex(root.entryKey(root.entries[resultList.currentIndex]), out);
        root.entries = out;
        if (out.length > 0) {
            resultList.currentIndex = Math.min(idx, out.length - 1);
            resultList.positionViewAtIndex(resultList.currentIndex, ListView.Contain);
        } else {
            resultList.currentIndex = -1;
        }
    }
    function launch(): void {
        filter.flush();
        if (root.cmdMode) {
            const rest = String(search.text ?? "").trim().slice(1).trim();
            const sel = root.entries[resultList.currentIndex] ?? null;
            if (filter.selMoved && sel) {
                if (sel.isCmd) {
                    root.record(sel.key);
                    root.run(["sh", "-c", sel.name]);
                } else {
                    root.record("bin:" + sel.name);
                    root.run([sel.name]);
                }
                return;
            }
            if (rest === "") {
                const picked = sel;
                if (!picked)
                    return;
                if (picked.isCmd) {
                    root.record(picked.key);
                    root.run(["sh", "-c", picked.name]);
                } else {
                    root.record("bin:" + picked.name);
                    root.run([picked.name]);
                }
                return;
            }
            const app = root.findApp(rest);
            if (app) {
                root.record("app:" + (app.id ?? ""));
                root.runApp(app);
            } else {
                root.record("cmd:" + rest);
                root.run(["sh", "-c", rest]);
            }
            return;
        }
        const entry = root.entries[resultList.currentIndex];
        if (!entry)
            return;
        if (entry.popup) {
            root.record(entry.key ?? ("popup:" + entry.popup));
            bar.togglePopup(entry.popup);
            return;
        }
        if (!entry.entry)
            return;
        root.record(entry.key ?? ("app:" + (entry.entry.id ?? entry.name ?? "")));
        root.runApp(entry.entry);
    }
    function findApp(rest: string): var {
        if (/\s/.test(rest))
            return null;
        const q = String(rest ?? "").toLowerCase();
        const cache = root.appsCache ?? [];
        for (const app of cache) {
            if (!app)
                continue;
            const rawCmd = Array.isArray(app.command) ? app.command : (typeof app.command === "string" ? [app.command] : []);
            const cmd = rawCmd.length > 0 ? rawCmd[0] : "";
            const base = String(cmd).split("/").pop().toLowerCase();
            if (base !== "" && base === q)
                return app;
            if (String(app.name ?? "").toLowerCase() === q)
                return app;
        }
        for (const app of cache) {
            if (!app)
                continue;
            const rawCmd = Array.isArray(app.command) ? app.command : (typeof app.command === "string" ? [app.command] : []);
            const cmd = rawCmd.length > 0 ? rawCmd[0] : "";
            const base = String(cmd).split("/").pop().toLowerCase();
            if (base !== "" && base.startsWith(q))
                return app;
            if (String(app.name ?? "").toLowerCase().startsWith(q))
                return app;
        }
        return null;
    }
    function asList(v): var {
        if (v === null || v === undefined)
            return [];
        if (typeof v === "string")
            return [v];
        if (Array.isArray(v))
            return v.slice();
        if (typeof v.length === "number") {
            const out = [];
            for (let i = 0; i < v.length; ++i)
                out.push(v[i]);
            return out;
        }
        return [v];
    }
    function sanitizeExec(cmd: var): var {
        const out = [];
        for (const a of root.asList(cmd)) {
            if (typeof a !== "string")
                continue;
            if (/^%(f|F|u|U|d|D|n|N|i|c|k|v|m)$/.test(a))
                continue;
            let b = a.replace(/%%/g, "%");
            const attached = b.match(/^(.*)=%[a-zA-Z]$/);
            if (attached)
                b = attached[1] + "=";
            if (b === "")
                continue;
            out.push(b);
        }
        return out;
    }
    function runApp(entry: var): void {
        if (!entry || !entry.command)
            return;
        const cmd = root.sanitizeExec(entry.command);
        if (cmd.length === 0)
            return;
        if (!entry.runInTerminal) {
            root.run(cmd);
            return;
        }
        const term = Quickshell.env("TERMINAL") ?? "foot";
        root.run([term].concat(cmd));
    }
    function run(cmd: var): void {
        bar.closePopups();
        Quickshell.execDetached(cmd);
    }
    PopupCard {
        SearchField {
            id: search
            accentBorder: root.cmdMode
            catchEscape: true
            onTextChanged: filter.schedule()
            onUpPressed: root.stepSelection(-1)
            onDownPressed: root.stepSelection(1)
            onAccepted: root.launch()
            onEscapePressed: search.releaseFocus()
        }
        ListView {
            id: resultList
            width: parent.width
            height: Services.Theme.listHeight(Services.Theme.listVisible)
            clip: true
            model: root.entries
            spacing: Services.Theme.listSpacing
            onCountChanged: clampListView(resultList)
            delegate: ResultRow {
                required property var modelData
                required property int index
                selected: resultList.currentIndex === index
                onClicked: {
                    resultList.currentIndex = index;
                    filter.selMoved = true;
                    root.launch();
                }
                NotificationIcon {
                    id: rowIcon
                    rawIcon: Services.Theme.launcherShowIcons ? (modelData.icon ?? modelData.entry?.icon ?? "") : ""
                    iconSize: 22
                    anchors {
                        left: parent.left
                        leftMargin: 10
                    }
                }
                Text {
                    anchors {
                        left: rowIcon.right
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: rowIcon.showIcon ? 10 : 0
                        rightMargin: 10
                    }
                    textFormat: Text.RichText
                    text: (modelData.isCmd ? "> " : "") + FilterUtils.hlName(modelData.name, root.hlQuery())
                    color: parent.selected ? Services.Theme.accentFg : parent.isHovered ? Services.Theme.fg : Services.Theme.dim
                    font.family: Services.Theme.font
                    font.pixelSize: Services.Theme.px12
                    elide: Text.ElideRight
                }
            }
        }
        HintText {
          id: hint
          text: "↹ move · ↵ launch · > command"
        }
    }
}
