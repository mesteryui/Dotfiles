pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    function applyTheme(wallpaperPath: string) {
        updateMatugenColors(wallpaperPath);
    }

    function updateMatugenColors(wallpaperPath: string) {
        if (wallpaperPath === "") return;

        // Ejecutamos matugen usando el modo reactivo del ConfigService
        Quickshell.execDetached([
            "matugen", 
            "image", wallpaperPath, 
            "--source-color-index", "0",
            "-t", ConfigService.configs.appearence.matugen.type
        ]);
    }
}