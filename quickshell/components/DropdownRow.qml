import QtQuick

SettingsRow {
    id: root
    property var options: []
    property string current: ""
    property bool dropEnabled: true
    property bool dropOpen: false
    property bool openUp: false
    property int cursor: 0
    signal headerClicked()
    signal optionClicked(string value)
    value: ""
    Dropdown {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        options: root.options
        current: root.current
        enabled: root.dropEnabled
        open: root.dropOpen
        selected: root.selected
        cursor: root.cursor
        openUp: root.openUp
        onHeaderClicked: root.headerClicked()
        onOptionClicked: value => root.optionClicked(value)
    }
}
