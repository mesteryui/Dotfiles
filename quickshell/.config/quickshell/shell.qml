//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000


import Quickshell
import QtQuick
import qs.Core.Services
import qs.Panels.System
import qs.Features.OSD
import qs.Panels.Wallpaper
import qs.Features.Notifications
import qs.Launcher
import qs.Lockscreen
import qs.Windows
ShellRoot {
    id: root
    settings.watchFiles: true

    ReloadPopup {}

    //AboutSystem {}   

    Component.onCompleted: {
        ConfigService.load()
    }

    AppLauncher {}

    // OSDs: Carga inmediata (pequeños y críticos)
    BrightnessOSD {}
    VolumeOSD {}
    BatteryOSD {}
    
    WallpaperMenu {}

    LazyLoader {
        id: powerButtonsLoader
        loading: true
        PowerButtons {}
    }
    Notifications {}
    Variants {
        model: Quickshell.screens
        delegate: Scope {
            id: delegateScope
            required property ShellScreen modelData
            Bar { screen: delegateScope.modelData }
        }
    }
    LockScreen {}
}
