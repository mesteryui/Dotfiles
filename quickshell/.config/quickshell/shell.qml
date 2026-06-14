//@ pragma UseQApplication
import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import "Services"
import "InterfaceThings"
import "OSD"

ShellRoot {
    id: root
    SpecialKeysOSD {}
    BrightnessOSD {}
    VolumeOSD {}
    BatteryOSD {}
    WallpaperMenu {}
    PowerButtons {}
    Bar {}
}
