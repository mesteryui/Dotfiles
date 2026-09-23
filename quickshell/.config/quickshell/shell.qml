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
import qs.Panels.Wallhaven
import qs.Features.CheatSheet
import qs.Windows
import QtQuick
import Quickshell
import "./Core/Log.js" as Log

ShellRoot {
    id: root

    settings.watchFiles: true

    Component.onCompleted: {
        Log.init(Quickshell.env("QS_LOG_LEVEL"));
        ConfigService.load();
        KeyboardThings.load();
        // Aplica el tema persistido al arrancar (no-op sin wallpaper).
        ThemeApplier.init();
    }

    Switcher {}

    // El launcher también es pesado (1200+ líneas + warmup de .desktop):
    // se incuba en background; el warmup vive dentro y se conserva.
    LazyLoader {
        loading: true
        component: AppLauncher {}
    }

    // Paneles pesados: LazyLoader los crea en los gaps entre frames sin
    // bloquear el primero. Son ventanas/Scopes (sin padre visual
    // necesario), el caso para el que está hecho LazyLoader. El IPC de
    // cada uno vive dentro de su ventana: hay un breve margen tras
    // arrancar sin handlers hasta que termina su incubación.
    LazyLoader {
        loading: true
        component: SettingsPanel {}
    }
    LazyLoader {
        loading: true
        component: PanelWithControls {}
    }
    LazyLoader {
        loading: true
        component: VolumeCenter {}
    }

    // Cargador de OSDs
    OsdManager {}

    LazyLoader {
        loading: true
        component: WallpaperMenu {}
    }

    LazyLoader {
        loading: true
        component: WallhavenWindow {}
    }

    ScreenRounding {}

    LazyLoader {
        loading: true
        component: PowerButtons {}
    }
    Notifications {}
    LazyLoader {
        loading: true
        component: Cheatsheet {}
    }
    PolkitWindow {}
    Bar {}
    LockScreen {}
}
