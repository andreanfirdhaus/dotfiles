import QtQuick
import Quickshell.Bluetooth
import Quickshell.Networking
import "../../components"
import "../../services" as Services

Grid {
    id: root
    required property var popup

    columns: 3
    columnSpacing: Services.Theme.listSpacing
    rowSpacing: Services.Theme.listSpacing
    width: parent.width

    function activateTile(i: int): void {
        const actions = [() => popup.bar.openFromPanel("wifi"), () => popup.bar.openFromPanel("bluetooth"), () => popup.toggleMicMute(), () => Services.Modes.toggleCaffeine(), () => Services.Modes.toggleDnd(), () => Services.Modes.toggleBluelight(), () => popup.cycleProfileTile(), () => popup.bar.openFromPanel("settings"), () => popup.bar.openFromPanel("power")];
        if (i >= 0 && i < actions.length)
            actions[i]();
    }
    Tile {
        glyph: Networking.wifiEnabled ? "󰤨" : "󰤭"
        label: "Wi-Fi"
        active: Networking.wifiEnabled
        selected: popup.selectedIndex === popup.firstTileIdx() + 0
        onClicked: root.activateTile(0)
    }
    Tile {
        glyph: Bluetooth.defaultAdapter?.enabled ? "󰂯" : "󰂲"
        label: "Bluetooth"
        active: Bluetooth.defaultAdapter?.enabled ?? false
        available: Bluetooth.defaultAdapter != null
        selected: popup.selectedIndex === popup.firstTileIdx() + 1
        onClicked: root.activateTile(1)
    }
    Tile {
        glyph: popup.micSource?.audio?.muted ? "󰍭" : "󰍬"
        label: "Mic"
        active: !(popup.micSource?.audio?.muted ?? false)
        available: popup.micSource?.audio != null
        selected: popup.selectedIndex === popup.firstTileIdx() + 2
        onClicked: root.activateTile(2)
    }
    Tile {
        glyph: "󰅶"
        label: "Caffeine"
        active: Services.Modes.caffeineActive
        selected: popup.selectedIndex === popup.firstTileIdx() + 3
        onClicked: root.activateTile(3)
    }
    Tile {
        glyph: ""
        label: "DND"
        active: Services.Modes.dndActive
        selected: popup.selectedIndex === popup.firstTileIdx() + 4
        onClicked: root.activateTile(4)
    }
    Tile {
        glyph: "󰖔"
        label: "Bluelight"
        active: Services.Modes.bluelightActive
        selected: popup.selectedIndex === popup.firstTileIdx() + 5
        onClicked: root.activateTile(5)
    }
    Tile {
        glyph: "󰓅"
        label: Services.Asus.available ? (Services.Asus.profile !== "" ? Services.Asus.profile : "Profile") : (Services.Power.profilesAvailable && Services.Power.profileName !== "" ? Services.Power.profileName : "Profile")
        active: Services.Asus.available ? Services.Asus.profile === "Performance" : Services.Power.profileName === "performance"
        available: Services.Asus.available || Services.Power.profilesAvailable
        selected: popup.selectedIndex === popup.firstTileIdx() + 6
        onClicked: root.activateTile(6)
    }
    Tile {
        glyph: ""
        label: "Settings"
        active: false
        selected: popup.selectedIndex === popup.firstTileIdx() + 7
        onClicked: root.activateTile(7)
    }
    Tile {
        glyph: "󰐥"
        label: "Power"
        active: false
        selected: popup.selectedIndex === popup.firstTileIdx() + 8
        onClicked: root.activateTile(8)
    }
}
