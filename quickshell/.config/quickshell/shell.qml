//@ pragma UseQApplication
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import "Core/Services" as Services
import "Components/Interface"
import "Features/OSD"
import "Widgets"

ShellRoot {
    id: root
    
    BrightnessOSD {}
    VolumeOSD {}
    BatteryOSD {}
    WallpaperMenu {}
    PowerButtons {}
    Variants {
        model: Quickshell.screens
        delegate: Scope {
            id: delegateScope
            required property ShellScreen modelData
            Bar { screen: delegateScope.modelData }
            // ← PowerButtons fuera de aquí
        }
    }
}
