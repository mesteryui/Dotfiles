pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel // IMPORTANTE: Este es el módulo reactivo

Singleton {
    id: root
    property alias wallpaperList: folderModel
    property string wallpaperDir: Quickshell.env("HOME") + "/Imágenes/Wallpapers"
    signal changed
    readonly property list<string> extensions: [ // TODO: add videos
        "jpg", "jpeg", "png", "webp", "avif", "bmp", "svg"]

    FolderListModel {
        id: folderModel
        folder: Qt.resolvedUrl(root.wallpaperDir)
        nameFilters: root.extensions.map(e => `*.${e}`) // Filtra solo imágenes
        showDirs: false
        showDotAndDotDot: false
        sortReversed: false
        sortField: FolderListModel.Name
    }
    Process {
        id: applyProcess
    }

    function apply(file: string): void {
        let fullPath = wallpaperDir + (wallpaperDir.endsWith("/") ? "" : "/") + file;
        root._apply(fullPath);
    }
    function _apply(file: string) {
        if (applyProcess.running) {
            applyProcess.running = false;
        }
        applyProcess.command = ["awww", "img", file, "--transition-type", "center"];
        applyProcess.running = true;
        ThemeApplier.applyTheme(file);
        root.changed();
    }
}
