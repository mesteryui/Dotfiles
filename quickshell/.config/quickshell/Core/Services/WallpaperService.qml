pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel // IMPORTANTE: Este es el módulo reactivo

Singleton {
    id: service
    property alias wallpaperList: folderModel
    readonly property string wallpaperDir: ConfigService.getConfig("wallpapersDir","/home/oscar/Imágenes/Wallpapers/")
    FolderListModel {
        id: folderModel
        folder: "file://" + service.wallpaperDir
        nameFilters: ["*.jpg", "*.png", "*.jpeg"] // Filtra solo imágenes
        showDirs: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
    }

    Process {
        id: applyProcess
    }

    function apply(file: string): void {
        let fullPath = wallpaperDir + (wallpaperDir.endsWith("/") ? "" : "/") + file;
        applyProcess.command = ["awww", "img", fullPath, "--transition-type", "center"];
        applyProcess.running = true;
        Quickshell.execDetached(["matugen", "image", fullPath, "--source-color-index", "0"]);
    }
}
