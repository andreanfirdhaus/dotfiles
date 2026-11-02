import QtQuick
import Quickshell
import "../components"
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
    readonly property bool runMode: String(search.text ?? "").trim().startsWith(">")
    readonly property string runQuery: String(search.text ?? "").trim().slice(1).trim().toLowerCase().slice(0, 256)
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
            Services.RunMode.refresh();
            Services.LaunchHistory.load();
            search.text = "";
            filter.selMoved = false;
            root.refilter();
        } else {
            root.appsCache = null;
            root.entries = [];
        }
    }
    Connections {
        target: Services.RunMode
        function onBinariesChanged() {
            if (root.visible && root.runMode)
                root.refilter();
        }
    }
    function refreshApps(): void {
        if (root.visible && !root.runMode) {
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
    Connections {
        target: Services.LaunchHistory
        function onLoadedChanged() {
            if (root.visible)
                root.refilter();
        }
    }
    function stepSelection(dir: int): void {
        filter.flush();
        stepListView(resultList, dir);
        filter.selMoved = true;
    }
    function refilter(): void {
        if (root.runMode)
            root.refilterRun(root.runQuery.slice(0, 256));
        else
            root.refilterApps(String(search.text ?? "").toLowerCase().trim().slice(0, 256));
    }
    function hlQuery(): string {
        return root.runMode ? root.runQuery : String(search.text ?? "").toLowerCase().trim();
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
                out.push({name: def.name, ln: name, key: key, popup: def.popup, icon: "", score: best, use: Services.LaunchHistory.countFor(key), last: Services.LaunchHistory.lastFor(key)});
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
                out.push({name: name, ln: String(name ?? "").toLowerCase(), key: appKey, entry: app, icon: app.icon ?? "", score: best, use: Services.LaunchHistory.countFor(appKey), last: Services.LaunchHistory.lastFor(appKey)});
            }
        }
        root.matchSystemActions(q, out);
        root.sortScored(out);
        root.applyResults(out.slice(0, Services.Theme.resultMax));
    }
    function refilterRun(q: string): void {
        const out = [];
        const seen = new Set();
        for (const b of Services.RunMode.binaries ?? []) {
            const score = FilterUtils.matchScoreLn(b.ln ?? "", q);
            if (score < 4) {
                seen.add(b.name);
                out.push({name: b.name, ln: b.ln ?? "", key: "bin:" + b.name, icon: "", score: score, use: Services.LaunchHistory.countFor("bin:" + b.name), last: Services.LaunchHistory.lastFor("bin:" + b.name)});
            }
        }
        for (const c of Services.LaunchHistory.recentCmds(root.runQuery, 5)) {
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
        if (root.runMode) {
            const rest = String(search.text ?? "").trim().slice(1).trim();
            const sel = root.entries[resultList.currentIndex] ?? null;
            if (filter.selMoved && sel) {
                if (sel.isCmd) {
                    Services.LaunchHistory.record(sel.key);
                    root.run(["sh", "-c", sel.name]);
                } else {
                    Services.LaunchHistory.record("bin:" + sel.name);
                    root.run([sel.name]);
                }
                return;
            }
            if (rest === "") {
                const picked = sel;
                if (!picked)
                    return;
                if (picked.isCmd) {
                    Services.LaunchHistory.record(picked.key);
                    root.run(["sh", "-c", picked.name]);
                } else {
                    Services.LaunchHistory.record("bin:" + picked.name);
                    root.run([picked.name]);
                }
                return;
            }
            const app = root.findApp(rest);
            if (app) {
                Services.LaunchHistory.record("app:" + (app.id ?? ""));
                root.runApp(app);
            } else {
                Services.LaunchHistory.record("cmd:" + rest);
                root.run(["sh", "-c", rest]);
            }
            return;
        }
        const entry = root.entries[resultList.currentIndex];
        if (!entry)
            return;
        if (entry.popup) {
            Services.LaunchHistory.record(entry.key ?? ("popup:" + entry.popup));
            bar.togglePopup(entry.popup);
            return;
        }
        if (!entry.entry)
            return;
        Services.LaunchHistory.record(entry.key ?? ("app:" + (entry.entry.id ?? entry.name ?? "")));
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
            accentBorder: root.runMode
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
