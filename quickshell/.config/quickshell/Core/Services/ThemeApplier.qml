pragma Singleton

import qs.Core.Modules
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string currentWallpaper: Persistent.persistence.currentWallpaper
    readonly property string matugenMode: ConfigService.configs.appearence.darkMode ? "dark" : "light"
    readonly property string matugenType: ConfigService.configs.appearence.matugen.type
    property Process proc: Process {}

    Connections {
        target: WallpaperService
        function onChanged(newWallpaper: string) {
            root.applyTheme(newWallpaper);
        }
    }

    // QML emitirá automáticamente estos eventos cuando el JsonAdapter actualice los valores subyacentes
    onMatugenModeChanged: root.updateMatugenColors(currentWallpaper)
    onMatugenTypeChanged: root.updateMatugenColors(currentWallpaper)

    function applyTheme(wallpaperPath: string) {
        root.updateMatugenColors(root.currentWallpaper);
    }

    function updateMatugenColors(wallpaperPath: string) {
        if (proc.running) {
            proc.running = false;
        }
        if (wallpaperPath === "")
            return;

        // Ejecutamos matugen usando el modo reactivo del ConfigService
        proc.command = ["matugen", "image", wallpaperPath, "--source-color-index", "0", "-t", root.matugenType, "-m", root.matugenMode];
        proc.running = true;
    }
}
