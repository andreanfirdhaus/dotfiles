import QtQuick
import "../services" as Services

Rectangle {
    id: root
    required property var clock
    property bool focused: false
    property var popup: null
    width: parent.width
    color: Services.Theme.bg
    border.color: Services.Theme.accent
    border.width: root.focused ? 1 : 0
    readonly property int gridHeight: 156
    readonly property int headerHeight: 26
    readonly property int weekdayHeight: 16
    readonly property int dateHeight: 16
    readonly property int fixedHeight: 2 * Services.Theme.popupPadding + root.headerHeight + root.dateHeight + root.weekdayHeight + root.gridHeight + 3 * Services.Theme.popupSpacing
    implicitHeight: root.fixedHeight
    property date viewDate: new Date()
    property int selectedDay: 1
    Component.onCompleted: root.resetToToday()
    function resetToToday(): void {
        const year = clock.date.getFullYear();
        const month = clock.date.getMonth();
        const day = clock.date.getDate();

        const newViewDate = new Date(year, month, 1);
        if (root.viewDate.getTime() !== newViewDate.getTime())
            root.viewDate = newViewDate;

        if (root.selectedDay !== day)
            root.selectedDay = day;
    }
    function stepMonth(offset: int): void {
        root.viewDate = new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() + offset, 1);
        root.clampSelection();
    }
    function clampSelection(): void {
        const max = root.daysInMonth(root.viewDate.getFullYear(), root.viewDate.getMonth());
        root.selectedDay = Math.max(1, Math.min(root.selectedDay, max));
    }
    function moveSelection(delta: int): void {
        const d = new Date(root.viewDate.getFullYear(), root.viewDate.getMonth(), root.selectedDay + delta);
        const newViewDate = new Date(d.getFullYear(), d.getMonth(), 1);
        if (root.viewDate.getTime() !== newViewDate.getTime())
            root.viewDate = newViewDate;
        root.selectedDay = d.getDate();
    }
    function openSelected(): void {
        root.openCalendar(root.selectedDay);
    }
    function daysInMonth(year: int, month: int): int {
        return new Date(year, month + 1, 0).getDate();
    }
    function weekStart(): int {
        return Qt.locale().firstDayOfWeek % 7;
    }
    function weekdayHeaders(): var {
        const names = ["S", "M", "T", "W", "T", "F", "S"];
        const start = root.weekStart();
        return names.slice(start).concat(names.slice(0, start));
    }
    readonly property int todayDay: clock.date.getDate()
    readonly property int todayMonth: clock.date.getMonth()
    readonly property int todayYear: clock.date.getFullYear()
    function isToday(day: int): bool {
        return day === root.todayDay && viewDate.getMonth() === root.todayMonth && viewDate.getFullYear() === root.todayYear;
    }
    readonly property var dayCells: {
        const first = (viewDate.getDay() - root.weekStart() + 7) % 7;
        const total = root.daysInMonth(viewDate.getFullYear(), viewDate.getMonth());
        const cells = [];
        for (let i = 0; i < first; ++i)
            cells.push(0);
        for (let d = 1; d <= total; ++d)
            cells.push(d);
        while (cells.length < 42)
            cells.push(0);
        return cells;
    }
    function openCalendar(day: int): void {
        if (day <= 0) return;
        const year = root.viewDate.getFullYear();
        const month = root.viewDate.getMonth() + 1;
        Qt.openUrlExternally(`https://calendar.google.com/calendar/u/0/r/day/${year}/${month}/${day}`);
    }
    Column {
        id: column
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: Services.Theme.popupPadding
        }
        spacing: Services.Theme.popupSpacing
        Row {
            width: parent.width
            height: root.headerHeight
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                horizontalAlignment: Text.AlignHCenter
                text: "󰅁"
                color: navLeft.containsMouse ? Services.Theme.fg : Services.Theme.dim
                font.family: Services.Theme.font
                font.pixelSize: Services.Theme.px14
                MouseArea {
                    id: navLeft
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.stepMonth(-1)
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 52
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatDateTime(root.viewDate, "MMMM yyyy")
                color: Services.Theme.fg
                font.family: Services.Theme.font
                font.pixelSize: Services.Theme.px13
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                horizontalAlignment: Text.AlignHCenter
                text: "󰅂"
                color: navRight.containsMouse ? Services.Theme.fg : Services.Theme.dim
                font.family: Services.Theme.font
                font.pixelSize: Services.Theme.px14
                MouseArea {
                    id: navRight
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.stepMonth(1)
                }
            }
        }
        Text {
            width: parent.width
            height: root.dateHeight
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDateTime(clock.date, "dddd, dd MMMM yyyy")
            color: Services.Theme.dim
            font.family: Services.Theme.font
            font.pixelSize: Services.Theme.px11
        }
        Row {
            width: parent.width
            height: root.weekdayHeight
            Repeater {
                model: root.weekdayHeaders()
                Text {
                    required property string modelData
                    width: parent.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Services.Theme.dim
                    font.family: Services.Theme.font
                    font.pixelSize: Services.Theme.px11
                }
            }
        }
        Grid {
            width: parent.width
            height: root.gridHeight
            columns: 7
            Repeater {
                model: root.dayCells
                Rectangle {
                    required property var modelData
                    readonly property bool isTodayCell: modelData > 0 && root.isToday(modelData)
                    readonly property bool isSelectedCell: modelData > 0 && modelData === root.selectedDay && root.focused
                    readonly property bool isHovered: dayArea.containsMouse && modelData > 0
                    readonly property bool showDay: root.focused || isTodayCell || isSelectedCell || isHovered
                    width: parent.width / 7
                    height: 26
                    color: showDay ? (isSelectedCell ? Services.Theme.accent : isTodayCell ? Services.Theme.activeBg : isHovered ? Services.Theme.hoverBg : Services.Theme.bg) : Services.Theme.transparent
                    border.width: isSelectedCell && isHovered ? 1 : 0
                    border.color: Services.Theme.accentFg
                    Text {
                        anchors.centerIn: parent
                        text: modelData === 0 ? "" : modelData
                        color: parent.isSelectedCell ? Services.Theme.accentFg : parent.isTodayCell || parent.isHovered ? Services.Theme.fg : Services.Theme.dim
                        font.family: Services.Theme.font
                        font.pixelSize: Services.Theme.px12
                    }
                    focus: true
                    Keys.onReturnPressed: root.openCalendar(root.selectedDay)
                    Keys.onSpacePressed: root.openCalendar(root.selectedDay)
                    Keys.onLeftPressed: root.moveSelection(-1)
                    Keys.onRightPressed: root.moveSelection(1)
                    Keys.onUpPressed: root.moveSelection(-1)
                    Keys.onDownPressed: root.moveSelection(1)
                    Keys.onEscapePressed: root.popup?.handleEscape()
                    MouseArea {
                        id: dayArea
                        anchors.fill: parent
                        enabled: parent.modelData > 0
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openCalendar(parent.modelData)
                    }
                }
            }
        }
    }
}
