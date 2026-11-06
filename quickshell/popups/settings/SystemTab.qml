import QtQuick
import "../../components"
import "../../services" as Services
import "../../services/SettingsUtil.js" as SettingsUtil

Column {
    id: root
    required property var popup

    visible: popup.tab === 1
    width: parent.width
    spacing: Services.Theme.popupSpacing
    Text {
        width: parent.width
        height: popup.sectionH
        verticalAlignment: Text.AlignVCenter
        text: "Idle"
        color: Services.Theme.dim
        font.family: Services.Theme.font
        font.pixelSize: Services.Theme.px11
    }
    Column {
        width: parent.width
        spacing: Services.Theme.listSpacing
        SettingsSliderRow {
            selected: popup.tab === 1 && popup.selectedIndex === 0
            title: "Dim display"
            value: SettingsUtil.fmtTimeout(Services.Settings.dimTimeout)
            sliderMinimum: 0
            sliderMaximum: 10
            sliderValue: Services.Settings.dimTimeout / 60
            onSliderMoved: value => Services.Settings.setDimTimeout(Math.round(value * 2) * 30)
        }
        SettingsSliderRow {
            selected: popup.tab === 1 && popup.selectedIndex === 1
            title: "Lock"
            value: SettingsUtil.fmtTimeout(Services.Settings.lockTimeout)
            sliderMinimum: 0
            sliderMaximum: 60
            sliderValue: Services.Settings.lockTimeout / 60
            onSliderMoved: value => Services.Settings.setLockTimeout(Math.round(value) * 60)
        }
        SettingsSliderRow {
            selected: popup.tab === 1 && popup.selectedIndex === 2
            title: "Screen off"
            value: SettingsUtil.fmtTimeout(Services.Settings.screenOffTimeout)
            sliderMinimum: 0
            sliderMaximum: 60
            sliderValue: Services.Settings.screenOffTimeout / 60
            onSliderMoved: value => Services.Settings.setScreenOffTimeout(Math.round(value) * 60)
        }
        SettingsSliderRow {
            selected: popup.tab === 1 && popup.selectedIndex === 3
            title: "Suspend"
            value: SettingsUtil.fmtTimeout(Services.Settings.suspendTimeout)
            sliderMinimum: 0
            sliderMaximum: 120
            sliderValue: Services.Settings.suspendTimeout / 60
            onSliderMoved: value => Services.Settings.setSuspendTimeout(Math.round(value / 5) * 300)
        }
    }
    Text {
        width: parent.width
        height: popup.sectionH
        verticalAlignment: Text.AlignVCenter
        text: "Battery"
        color: Services.Theme.dim
        font.family: Services.Theme.font
        font.pixelSize: Services.Theme.px11
    }
    Column {
        width: parent.width
        spacing: Services.Theme.listSpacing
        z: popup.openDropdown === popup.sysIdx(6) ? 50 : 0
        SettingsSliderRow {
            visible: Services.Power.asusAvailable
            selected: popup.tab === 1 && popup.selectedIndex === 4
            title: "Charge limit"
            value: Services.Power.asusChargeLimit + "%"
            sliderMinimum: 20
            sliderMaximum: 100
            sliderValue: Services.Power.asusChargeLimit
            onSliderMoved: value => Services.Power.setAsusChargeLimit(Math.round(value / 5) * 5)
        }
        SettingsSliderRow {
            selected: popup.tab === 1 && popup.selectedIndex === popup.sysIdx(4)
            title: "Low battery"
            value: Services.Settings.lowBatteryPct + "%"
            sliderMinimum: 5
            sliderMaximum: 50
            sliderValue: Services.Settings.lowBatteryPct
            onSliderMoved: value => Services.Settings.setLowBatteryPct(Math.round(value / 5) * 5)
        }
        SettingsSliderRow {
            selected: popup.tab === 1 && popup.selectedIndex === popup.sysIdx(5)
            title: "Critical battery"
            titleWidth: 124
            value: Services.Settings.criticalBatteryPct + "%"
            sliderMinimum: 3
            sliderMaximum: 30
            sliderValue: Services.Settings.criticalBatteryPct
            onSliderMoved: value => Services.Settings.setCriticalBatteryPct(Math.round(value / 2) * 2)
        }
        DropdownRow {
            selected: popup.tab === 1 && popup.selectedIndex === popup.sysIdx(6)
            title: "Lid close"
            z: popup.openDropdown === popup.sysIdx(6) ? 100 : 0
            options: Services.Power.lidOptions
            current: Services.Settings.lidCloseAction
            dropOpen: popup.openDropdown === popup.sysIdx(6)
            cursor: popup.dropCursor
            onHeaderClicked: {
                popup.selectedIndex = popup.sysIdx(6);
                popup.toggleDrop(popup.sysIdx(6));
            }
            onOptionClicked: value => {
                popup.selectedIndex = popup.sysIdx(6);
                popup.applyDropValue(popup.sysIdx(6), value);
                popup.closeDrop();
            }
        }
    }
    Text {
        width: parent.width
        height: popup.sectionH
        verticalAlignment: Text.AlignVCenter
        text: "Profiles"
        color: Services.Theme.dim
        font.family: Services.Theme.font
        font.pixelSize: Services.Theme.px11
    }
    Column {
        width: parent.width
        spacing: Services.Theme.listSpacing
        z: popup.openDropdown === popup.sysIdx(7) || popup.openDropdown === popup.sysIdx(8) ? 50 : 0
        DropdownRow {
            selected: popup.tab === 1 && popup.selectedIndex === popup.sysIdx(7)
            title: "Active profile"
            z: popup.openDropdown === popup.sysIdx(7) ? 100 : 0
            options: popup.dropdownOptions(popup.sysIdx(7))
            current: popup.dropdownCurrent(popup.sysIdx(7))
            dropEnabled: popup.dropEnabled(popup.sysIdx(7))
            dropOpen: popup.openDropdown === popup.sysIdx(7)
            cursor: popup.dropCursor
            openUp: true
            onHeaderClicked: {
                popup.selectedIndex = popup.sysIdx(7);
                popup.toggleDrop(popup.sysIdx(7));
            }
            onOptionClicked: value => {
                popup.selectedIndex = popup.sysIdx(7);
                popup.applyDropValue(popup.sysIdx(7), value);
                popup.closeDrop();
            }
        }
        DropdownRow {
            selected: popup.tab === 1 && popup.selectedIndex === popup.sysIdx(8)
            title: "On battery"
            z: popup.openDropdown === popup.sysIdx(8) ? 100 : 0
            options: Services.Power.profileOptions
            current: Services.Power.profilesAvailable ? Services.Settings.powerProfileOnBattery : "no ppd"
            dropOpen: popup.openDropdown === popup.sysIdx(8)
            cursor: popup.dropCursor
            openUp: true
            onHeaderClicked: {
                popup.selectedIndex = popup.sysIdx(8);
                popup.toggleDrop(popup.sysIdx(8));
            }
            onOptionClicked: value => {
                popup.selectedIndex = popup.sysIdx(8);
                popup.applyDropValue(popup.sysIdx(8), value);
                popup.closeDrop();
            }
        }
    }
    Text {
        width: parent.width
        height: 30
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: "Idle rows write hypridle.conf. Lid close prompts to update logind (root + reboot). Power key suspends."
        color: Services.Theme.dim
        font.family: Services.Theme.font
        font.pixelSize: Services.Theme.px10
    }
}
