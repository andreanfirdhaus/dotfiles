import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../components"
import "../components/FilterUtils.js" as FilterUtils
import "../components/PasteUtils.js" as PasteUtils
import "../services" as Services
import "../services/SettingsUtil.js" as U
import "../emoji/emoji.js" as EmojiData
BasePopup {
    id: root
    anchorMode: "middle"
    implicitWidth: Services.Theme.settingsWidth
    implicitHeight: 16 + Services.Theme.rowHeight + Services.Theme.popupSpacing + resultGrid.cellHeight * root.gridRows
    readonly property int gridCols: 10
    readonly property int gridRows: 9
    function escArmed(): bool {
        return !search.hasFocus;
    }
    function quitArmed(): bool {
        return !search.hasFocus;
    }
    Shortcut { sequence: "Down"; enabled: root.visible && !search.hasFocus; onActivated: root.stepSelection(1, root.gridCols) }
    Shortcut { sequence: "Up"; enabled: root.visible && !search.hasFocus; onActivated: root.stepSelection(-1, root.gridCols) }
    Shortcut { sequence: "Left"; enabled: root.visible && !search.hasFocus; onActivated: root.stepSelection(-1, 1) }
    Shortcut { sequence: "Right"; enabled: root.visible && !search.hasFocus; onActivated: root.stepSelection(1, 1) }
    Shortcut { sequence: "Return"; enabled: root.visible && !search.hasFocus; onActivated: root.pick() }
    Shortcut { sequence: "Enter"; enabled: root.visible && !search.hasFocus; onActivated: root.pick() }
    Shortcut { sequence: "/"; enabled: root.visible && !search.hasFocus; onActivated: search.forceFocus() }
    Shortcut { sequence: "j"; enabled: root.visible && !search.hasFocus; onActivated: root.stepSelection(1, root.gridCols) }
    Shortcut { sequence: "k"; enabled: root.visible && !search.hasFocus; onActivated: root.stepSelection(-1, root.gridCols) }
    Shortcut { sequence: "h"; enabled: root.visible && !search.hasFocus; onActivated: root.stepSelection(-1, 1) }
    Shortcut { sequence: "l"; enabled: root.visible && !search.hasFocus; onActivated: root.stepSelection(1, 1) }
    property var entries: []
    property string activeAddress: ""
    property string activeClass: ""
    readonly property string runtimeDir: {
        const r = Quickshell.env("XDG_RUNTIME_DIR") ?? "";
        if (r !== "")
            return r;
        const home = Quickshell.env("HOME") ?? "";
        if (home !== "")
            return home + "/.cache";
        return "/tmp";
    }
    property string clipTmp: root.runtimeDir + "/qs-emoji-clip-restore"
    function validAddress(addr: string): bool {
        return PasteUtils.validAddress(addr);
    }
    FilterState {
        id: filter
        onRefilterRequested: {
            if (root.visible)
                root.refilter();
        }
    }
    function groupRank(g: int): int {
        if (g < 0)
            return 99;
        if (g <= 1)
            return g;
        if (g === 2)
            return 0;
        if (g <= 9)
            return g - 1;
        return 99;
    }
    onVisibleChanged: {
        if (visible) {
            root.loadRecents();
            search.text = "";
            filter.selMoved = false;
            root.activeAddress = "";
            root.activeClass = "";
            root.pendingEmoji = "";
            focusProbe.running = true;
            root.refilter();
        } else {
            root.entries = [];
            if (focusProbe.running)
                focusProbe.running = false;
        }
    }

    property var recents: []
    property bool recentsLoaded: false
    property bool recentsLoading: false
    property bool recentsLoadDone: false
    readonly property string recentsFile: U.dataPath("emoji-recents.json")
    onRecentsChanged: {
        if (root.visible)
            root.refilter();
    }
    function loadRecents(): void {
        if (root.recentsLoaded || root.recentsLoading)
            return;
        if (root.recentsFile === "")
            return;
        root.recentsLoading = true;
        recentsReader.running = true;
    }
    function recordEmoji(ch: string): void {
        if (typeof ch !== "string" || ch === "" || ch.length > 32)
            return;
        if (root.recentsFile === "")
            return;
        root.recents = [ch].concat(root.recents.filter(c => c !== ch)).slice(0, 30);
        recentsWriter.write(root.recentsFile, JSON.stringify(root.recents), false);
    }
    Services.AtomicWriter {
        id: recentsWriter
    }
    Process {
        id: recentsReader
        command: ["cat", root.recentsFile]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.recentsLoadDone)
                    return;
                root.recentsLoadDone = true;
                const duringLoad = root.recents.slice();
                try {
                    if (text.length > 65536)
                        throw "history file too large";
                    const arr = JSON.parse(text);
                    if (Array.isArray(arr)) {
                        const fromFile = arr.filter(c => typeof c === "string" && c !== "" && c.length <= 32).slice(0, 30);
                        const seen = new Set();
                        const merged = [];
                        for (const c of duringLoad.concat(fromFile)) {
                            if (seen.has(c))
                                continue;
                            seen.add(c);
                            merged.push(c);
                            if (merged.length >= 30)
                                break;
                        }
                        root.recents = merged;
                    }
                } catch (_) {
                    if (duringLoad.length > 0)
                        root.recents = duringLoad.slice(0, 30);
                }
                root.recentsLoading = false;
                root.recentsLoaded = true;
            }
        }
        onExited: exitCode => {
            if (root.recentsLoadDone)
                return;
            root.recentsLoadDone = true;
            if (root.recentsLoading) {
                root.recentsLoading = false;
                root.recentsLoaded = true;
            }
        }
    }
    function stepSelection(dir: int, stride: int): void {
        filter.flush();
        stepListView(resultGrid, dir, stride);
        filter.selMoved = true;
    }
    function refilter(): void {
        const q = String(search.text ?? "").toLowerCase().trim().slice(0, 256);
        const main = [];
        for (const e of EmojiData.EMOJI) {
            const score = FilterUtils.matchScoreLn(e[2], q);
            if (score < 3)
                main.push({ch: e[0], name: e[1], g: e[3], key: e[0], score: q === "" ? 1 : score});
        }
        main.sort((a, b) => (a.score - b.score) || (root.groupRank(a.g) - root.groupRank(b.g)) || ((a.name < b.name) ? -1 : (a.name > b.name) ? 1 : 0));
        let out = main.slice(0, Services.Theme.resultMax * 5);
        if (q === "") {
            const seen = new Set();
            const head = [];
            for (const ch of root.recents) {
                if (seen.has(ch))
                    continue;
                seen.add(ch);
                const e = root.entryFor(ch);
                if (e)
                    head.push({ch: ch, name: e[1], g: e[3], key: ch, score: 0});
            }
            out = head.concat(main.filter(m => !seen.has(m.ch))).slice(0, Services.Theme.resultMax * 5);
        }
        root.applyResults(out);
    }
    property var emojiByChar: null
    function entryFor(ch: string): var {
        if (!root.emojiByChar) {
            const m = Object.create(null);
            for (const e of EmojiData.EMOJI)
                m[e[0]] = e;
            root.emojiByChar = m;
        }
        return root.emojiByChar[ch] ?? null;
    }
    function applyResults(out: var): void {
        const idx = filter.keptIndex((root.entries[resultGrid.currentIndex] ?? {}).key ?? "", out);
        root.entries = out;
        if (out.length > 0) {
            resultGrid.currentIndex = Math.min(idx, out.length - 1);
            resultGrid.positionViewAtIndex(resultGrid.currentIndex, GridView.Contain);
        } else {
            resultGrid.currentIndex = -1;
        }
    }
    function pick(): void {
        filter.flush();
        const entry = root.entries[resultGrid.currentIndex];
        if (!entry || saveProbe.running || restoreProbe.running || pasteTimer.running || restoreTimer.running)
            return;
        if (!root.validAddress(root.activeAddress)) {
            Services.Notifs.notify({app: "emoji", summary: "No target window", timeout: Services.Theme.osdTimeout});
            return;
        }
        if (typeof entry.ch !== "string" || entry.ch === "" || entry.ch.length > 32)
            return;
        if (root.clipTmp === "" || !root.clipTmp.endsWith("/qs-emoji-clip-restore"))
            return;
        root.recordEmoji(entry.ch);
        root.pendingEmoji = entry.ch;
        saveProbe.command = ["sh", "-c", 'f="$1"; e="$2"; cliphist list 2>/dev/null | head -n 1 | cut -f1 > "$f.maxid"; rm -f "$f" "$f.type"; if t=$(wl-paste --list-types 2>/dev/null | head -n 1) && [ -n "$t" ]; then printf "%s" "$t" > "$f.type"; wl-paste -t "$t" > "$f" 2>/dev/null || rm -f "$f" "$f.type"; fi; printf "%s" "$e" | wl-copy', "qs", root.clipTmp, entry.ch];
        saveProbe.running = true;
        saveTimeout.restart();
    }
    Process {
        id: saveProbe
        onExited: exitCode => {
            saveTimeout.stop();
            if (exitCode !== 0) {
                Services.Notifs.notify({app: "emoji", summary: "Copy failed", body: "wl-copy failed", timeout: 5000});
                return;
            }
            bar.closePopups();
            pasteTimer.start();
        }
    }
    Timer {
        id: saveTimeout
        interval: 8000
        repeat: false
        onTriggered: {
            if (saveProbe.running) {
                saveProbe.running = false;
                Services.Notifs.notify({app: "emoji", summary: "Copy timed out", body: "wl-copy hung", timeout: 5000});
            }
        }
    }
    Timer {
        id: pasteTimer
        interval: Services.Theme.grabDelay
        repeat: false
        onTriggered: root.pasteIntoActive()
    }
    function pasteIntoActive(): void {
        if (!root.validAddress(root.activeAddress))
            return;
        const mods = PasteUtils.pasteMods(root.activeClass);
        Hyprland.dispatch("hl.dsp.send_shortcut({ mods = \"" + mods + "\", key = \"V\", window = \"address:" + root.activeAddress + "\" })");
        restoreTimer.start();
    }
    Timer {
        id: restoreTimer
        interval: 500
        repeat: false
        onTriggered: {
            restoreProbe.command = ["sh", "-c", 'f="$1"; e="$2"; if [ "$(wl-paste 2>/dev/null)" != "$e" ]; then rm -f "$f" "$f.type" "$f.maxid" "$f.all"; exit 0; fi; if [ -f "$f.type" ] && [ -f "$f" ]; then t=$(cat "$f.type"); case "$t" in text/*|TEXT|STRING|UTF8_STRING) wl-copy < "$f";; *) wl-copy -t "$t" < "$f";; esac 2>/dev/null || wl-copy < "$f"; else wl-copy --clear; fi; sleep 0.3; cliphist list 2>/dev/null > "$f.all"; if [ -s "$f.maxid" ]; then m=$(cat "$f.maxid"); while IFS= read -r line; do id=$(printf "%s\\n" "$line" | cut -f1); case "$id" in ""|*[!0-9]*) continue;; esac; if [ "$id" -gt "$m" ] 2>/dev/null; then printf "%s\\n" "$line" | cliphist delete; fi; done < "$f.all"; else line=$(grep -F -- "$e" "$f.all" 2>/dev/null | tail -n 1); [ -n "$line" ] && printf "%s\\n" "$line" | cliphist delete; fi; rm -f "$f" "$f.type" "$f.maxid" "$f.all"', "qs", root.clipTmp, root.pendingEmoji];
            restoreProbe.running = true;
        }
    }
    property string pendingEmoji: ""
    Process {
        id: restoreProbe
        onExited: exitCode => {
            if (exitCode !== 0)
                Services.Notifs.notify({app: "emoji", summary: "Clipboard restore failed", timeout: 5000});
        }
    }
    Process {
        id: focusProbe
        command: ["sh", "-c", "hyprctl activewindow -j 2>/dev/null | jq -r '[.address,.class] | @tsv' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const r = PasteUtils.parseFocusProbe(text);
                root.activeAddress = r.address;
                root.activeClass = r.winClass;
            }
        }
    }
    PopupCard {
        SearchField {
            id: search
            placeholder: "/ to search"
            catchEscape: true
            onTextChanged: filter.schedule()
            onUpPressed: root.stepSelection(-1, root.gridCols)
            onDownPressed: root.stepSelection(1, root.gridCols)
            onAccepted: root.pick()
            onEscapePressed: search.releaseFocus()
        }
        GridView {
            id: resultGrid
            width: parent.width
            height: cellHeight * root.gridRows
            clip: true
            model: root.entries
            cellWidth: width / root.gridCols
            cellHeight: 42
            onCountChanged: clampListView(resultGrid)
            delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property bool selected: resultGrid.currentIndex === index
                readonly property bool hovered: cellArea.containsMouse
                width: GridView.view.cellWidth
                height: GridView.view.cellHeight
                color: selected ? Services.Theme.accent : hovered ? Services.Theme.hoverBg : Services.Theme.transparent
                border.width: selected && hovered ? 1 : 0
                border.color: Services.Theme.accentFg
                MouseArea {
                    id: cellArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        resultGrid.currentIndex = index;
                        filter.selMoved = true;
                        root.pick();
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: modelData.ch
                    font.family: "Noto Color Emoji"
                    font.pixelSize: 24
                }
            }
        }
    }
}
