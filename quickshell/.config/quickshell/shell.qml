//@ pragma UseQApplication
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import Quickshell
import QtQuick
import qs.Core.Services
import qs.Features.WindowSwitcher
import qs.Panels.System
import qs.Panels.Polkit
import qs.Features.OSD
import qs.Panels.Controls
import qs.Panels.Wallpaper
import qs.Features.Notifications
import qs.Lockscreen
import qs.Bar
import qs.Features.CheatSheet
import qs.Windows

ShellRoot {
    id: root
    settings.watchFiles: true

    //ReloadPopup {}

    Switcher {}

    //AboutSystem {}

    Component.onCompleted: {
        ConfigService.load();
        KeyboardThings.load();
    }
    SettingsPanel {}
    PanelWithControls {}

    // OSDs: Carga inmediata (pequeños y críticos)
    BrightnessOSD {}
    VolumeOSD {}
    SpecialKeysOSD {}
    BatteryOSD {}
    GameModeOSD {}

    WallpaperMenu {}

    ScreenRounding {}

    PowerButtons {}
    Notifications {}
    Cheatsheet {}
    PolkitWindow {}
    Bar {}
    LockScreen {}
}
