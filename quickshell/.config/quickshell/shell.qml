//@ pragma UseQApplication
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import qs.Core.Services as Services
import qs.Components.Interface
import qs.Features.OSD
import qs.Widgets

ShellRoot {
    id: root
    settings.watchFiles: true
    
    // OSDs: Carga inmediata (pequeños y críticos)
    BrightnessOSD {}
    VolumeOSD {}
    BatteryOSD {}
    
    // Widgets pesados: LazyLoader para no bloquear el inicio
    LazyLoader {
        id: wallpaperMenuLoader
        loading: true
        WallpaperMenu {}
    }

    LazyLoader {
        id: powerButtonsLoader
        loading: true
        PowerButtons {}
    }

    Variants {
        model: Quickshell.screens
        delegate: Scope {
            id: delegateScope
            required property ShellScreen modelData
            Bar { screen: delegateScope.modelData }
        }
    }
}
