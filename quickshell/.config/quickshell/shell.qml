//@ pragma UseQApplication
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import qs.Core.Services
import qs.Features.WindowSwitcher
import qs.Panels.System
import qs.Panels.Polkit
import qs.Features.OSD
import qs.Panels.Controls
import qs.Panels.Wallpaper
import qs.Features.Notifications
import qs.Lockscreen
import qs.Launcher
import qs.Bar
import qs.Panels.Volume
import qs.Features.CheatSheet
import qs.Windows
import QtQuick
import Quickshell

ShellRoot {
    id: root

    settings.watchFiles: true

    Component.onCompleted: {
        ConfigService.load();
        KeyboardThings.load();
        // Aplica el tema persistido al arrancar (no-op sin wallpaper).
        ThemeApplier.init();
    }

    // Cada componente pesado es un Scope ligero con LazyLoader interno:
    // el IPC/atajos responden desde el arranque y la ventana solo se
    // instancia al abrir (y se destruye al cerrar). Nada de loading:true
    // aquí: eso era lo que inflaba la RAM al arrancar.
    Switcher {}
    AppLauncher {}
    SettingsPanel {}
    PanelWithControls {}
    VolumeCenter {}

    // Cargador de OSDs
    OsdManager {}

    WallpaperMenu {}

    ScreenRounding {}

    PowerButtons {}
    Notifications {}
    Cheatsheet {}
    PolkitWindow {}
    Bar {}
    LockScreen {}
}
