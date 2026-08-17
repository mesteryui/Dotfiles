pragma Singleton
import QtQuick
import Quickshell
import qs.Core.Modules

Singleton {
    id: root

    readonly property string currentWallpaper: Persistent.persistence.currentWallpaper
    readonly property string matugenMode: ConfigService.configs.appearence.darkMode ? "dark" : "light"

    Connections {
        target: ConfigService.configs.appearence
        function onDarkModeChanged() {
            root.updateMatugenColors(root.currentWallpaper)
        }
    }

    Connections {
        target: ConfigService.configs.appearence.matugen
        function onTypeChanged() {
            root.updateMatugenColors(root.currentWallpaper)
        }
    }

    function applyTheme(wallpaperPath: string) {
        Persistent.persistence.currentWallpaper = wallpaperPath
        updateMatugenColors(root.currentWallpaper);
    }

    function updateMatugenColors(wallpaperPath: string) {
        if (wallpaperPath === "") return;

        // Ejecutamos matugen usando el modo reactivo del ConfigService
        Quickshell.execDetached([
            "matugen", 
            "image", wallpaperPath, 
            "--source-color-index", "0",
            "-t", ConfigService.configs.appearence.matugen.type,
            "-m", root.matugenMode
        ]);
    }
}