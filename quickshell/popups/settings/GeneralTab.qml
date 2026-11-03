import QtQuick
import "../../components"
import "../../services" as Services

Column {
    id: root
    required property var popup
    property alias wallList: wallList

    visible: popup.tab === 0
    width: parent.width
    spacing: Services.Theme.popupSpacing
    Text {
        width: parent.width
        height: popup.sectionH
        verticalAlignment: Text.AlignVCenter
        text: "Appearance"
        color: popup.tab === 0 && popup.selectedIndex === 0 ? Services.Theme.fg : Services.Theme.dim
        font.family: Services.Theme.font
        font.pixelSize: Services.Theme.px11
    }
    DropdownRow {
        selected: popup.tab === 0 && popup.selectedIndex === 0
        title: "Palette"
        z: popup.paletteDropOpen ? 100 : 0
        options: popup.paletteOptions()
        current: Services.Theme.activeLabel
        dropOpen: popup.paletteDropOpen
        cursor: popup.dropCursor
        onHeaderClicked: {
            popup.selectedIndex = 0;
            popup.togglePaletteDrop();
        }
        onOptionClicked: value => {
            popup.selectedIndex = 0;
            popup.applyPalette(value);
            popup.closeDrop();
        }
    }
    Row {
        width: parent.width
        height: popup.swatchH
        spacing: Services.Theme.listSpacing
        Repeater {
            model: Services.Theme.swatches
            delegate: Rectangle {
                required property var modelData
                width: Math.max(1, Math.floor((parent.width - (Services.Theme.swatches.length - 1) * Services.Theme.listSpacing) / Services.Theme.swatches.length))
                height: popup.swatchH
                color: modelData
                border.width: 1
                border.color: Services.Theme.border
            }
        }
    }
    Text {
        width: parent.width
        height: popup.themeHintH
        verticalAlignment: Text.AlignVCenter
        text: "btop · yazi · lazygit apply on next launch"
        color: Services.Theme.dim
        font.family: Services.Theme.font
        font.pixelSize: Services.Theme.px10
        elide: Text.ElideRight
    }
    Text {
        width: parent.width
        height: popup.sectionH
        verticalAlignment: Text.AlignVCenter
        text: Services.Settings.wallpapers.length > 0 ? "Wallpaper  ·  " + Services.Settings.wallpapers.length : "Wallpaper"
        color: popup.tab === 0 && popup.selectedIndex === popup.themeBase ? Services.Theme.fg : Services.Theme.dim
        font.family: Services.Theme.font
        font.pixelSize: Services.Theme.px11
    }
    Column {
        width: parent.width
        spacing: Services.Theme.listSpacing
        Item {
            width: parent.width
            height: popup.wpListH + popup.wallWrapPad * 2
            visible: popup.wpCount > 0
            Rectangle {
                anchors.fill: parent
                color: Services.Theme.transparent
                border.width: 1
                border.color: popup.tab === 0 && popup.selectedIndex === popup.themeBase ? Services.Theme.accent : Services.Theme.border
            }
            GridView {
                id: wallList
                anchors.fill: parent
                anchors.margins: popup.wallWrapPad
                clip: true
                flow: GridView.FlowLeftToRight
                cellWidth: Math.max(1, Math.floor(width / popup.wpCols))
                cellHeight: popup.wpCellH
                cacheBuffer: popup.wpCellH * 3
                model: Services.Settings.wallpapers
                onCountChanged: popup.syncWallCursor()
                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool current: modelData === Services.Settings.wallpaperOverride
                    readonly property bool selected: popup.wallFocus && wallList.currentIndex === index
                    readonly property bool hovered: thumbHover.containsMouse
                    width: GridView.view.cellWidth
                    height: GridView.view.cellHeight
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        color: cell.selected ? Services.Theme.activeBg : cell.hovered ? Services.Theme.hoverBg : Services.Theme.surface
                        border.width: cell.selected ? 1 : 0
                        border.color: cell.hovered ? Services.Theme.fg : Services.Theme.accent
                        clip: true
                        Image {
                            anchors {
                                top: parent.top
                                left: parent.left
                                right: parent.right
                                bottom: nameLabel.top
                                topMargin: 4
                                leftMargin: 4
                                rightMargin: 4
                                bottomMargin: 4
                            }
                            source: "file://" + cell.modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            mipmap: true
                            sourceSize.width: 256
                        }
                        Text {
                            id: nameLabel
                            anchors {
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                                leftMargin: 6
                                rightMargin: 6
                                bottomMargin: 3
                            }
                            height: 17
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: (cell.current ? "✓ " : "") + String(cell.modelData).split("/").pop()
                            color: cell.selected ? Services.Theme.fg : cell.current ? Services.Theme.accent : cell.hovered ? Services.Theme.fg : Services.Theme.dim
                            font.family: Services.Theme.font
                            font.pixelSize: Services.Theme.px10
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            id: thumbHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wallList.currentIndex = cell.index;
                                popup.wallCursor = cell.index;
                                popup.selectedIndex = popup.themeBase;
                                popup.wallFocus = false;
                                Services.Settings.setWallpaper(cell.modelData);
                            }
                        }
                    }
                }
            }
        }
        Text {
            width: parent.width
            visible: popup.wpCount === 0
            wrapMode: Text.WordWrap
            text: "Add images to ~/dotfiles/wallpapers or ~/Pictures/Wallpapers"
            color: Services.Theme.dim
            font.family: Services.Theme.font
            font.pixelSize: Services.Theme.px12
        }
        Text {
            width: parent.width
            height: popup.wallHintH
            visible: popup.wpCount > 0
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: popup.wallFocus ? "Arrows move · Enter applies · Esc exits" : "Enter to browse with keyboard"
            color: Services.Theme.dim
            font.family: Services.Theme.font
            font.pixelSize: Services.Theme.px10
        }
    }
    Text {
        width: parent.width
        height: popup.sectionH
        verticalAlignment: Text.AlignVCenter
        text: "Mouse & touchpad"
        color: Services.Theme.dim
        font.family: Services.Theme.font
        font.pixelSize: Services.Theme.px11
    }
    Column {
        width: parent.width
        spacing: Services.Theme.listSpacing
        SettingsSliderRow {
            title: "Sensitivity"
            value: Services.Settings.sensitivity.toFixed(1)
            selected: popup.tab === 0 && popup.selectedIndex === popup.inputBase + 0
            sliderMinimum: -1
            sliderMaximum: 1
            sliderValue: Services.Settings.sensitivity
            onSliderMoved: value => Services.Settings.setSensitivity(value)
        }
        SettingsSliderRow {
            title: "Touchpad scroll"
            value: Services.Settings.touchScroll.toFixed(1)
            selected: popup.tab === 0 && popup.selectedIndex === popup.inputBase + 1
            sliderMinimum: 0.1
            sliderMaximum: 2
            sliderValue: Services.Settings.touchScroll
            onSliderMoved: value => Services.Settings.setTouchScroll(value)
        }
        SettingsRow {
            title: "Natural scroll"
            value: Services.Settings.naturalScroll ? "On" : "Off"
            selected: popup.tab === 0 && popup.selectedIndex === popup.inputBase + 2
            SettingsSwitch {
                on: Services.Settings.naturalScroll
                onToggled: Services.Settings.setNaturalScroll(!Services.Settings.naturalScroll)
            }
        }
    }
}
