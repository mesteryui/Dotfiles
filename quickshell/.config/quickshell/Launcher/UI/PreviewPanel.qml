// --- PreviewPanel: panel lateral de preview del launcher ---
// Solo donde es imprescindible: clip (texto completo/imagen),
// files image/text/audio/video, system con imagePath (fastfetch).
// En el resto de menús se oculta y la lista ocupa todo el ancho.
// Entradas: item actual + estado de preview que orquesta AppLauncher.
pragma ComponentBehavior: Bound

import qs.Core
import qs.Primitives
import "../Base/MenuModes.js" as MenuModes
import "../Base/ItemKinds.js" as ItemKinds
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string activeMode: ""
    property var cur
    property bool previewOk: false
    property string previewPath: ""
    property string previewText: ""
    property string clipText: ""
    property string fileTooLargeText: "Archivo demasiado grande para previsualizar"

    readonly property bool hasPreview: MenuModes.needsPreview(root.activeMode, root.cur)

    visible: hasPreview
    Layout.preferredWidth: hasPreview ? 380 : 0
    Layout.fillHeight: true
    radius: 20
    color: Appearance.md3.surface_container_low

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // Imagen: archivos de imagen, carátulas/thumbs multimedia o clipboard
        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 340
            Layout.preferredHeight: 300
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            // Las rutas llevan el cid/pid (únicas por contenido): cachear
            // evita re-decodificar al re-seleccionar el mismo item.
            cache: true
            // Decodificar acotado: más rápido y menos memoria.
            sourceSize.width: 680
            sourceSize.height: 600
            visible: root.cur && ((root.cur.imagePath || "") !== "" || (ItemKinds.hasLivePreview(root.cur) && root.previewOk))
            source: {
                if (!root.cur)
                    return "";
                if ((root.cur.imagePath || "") !== "")
                    return root.cur.imagePath;
                if (root.previewOk)
                    return "file://" + root.previewPath;
                return "";
            }
        }

        // Icono / emoji grande cuando no hay imagen ni texto
        // (en clip-texto se oculta: el cuerpo ya es el texto).
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 96
            Layout.preferredHeight: 96
            visible: root.cur && ((root.cur.imagePath || "") === "") && !(ItemKinds.hasLivePreview(root.cur) && root.previewOk) && !(ItemKinds.hasTextPreview(root.cur) && root.previewText !== "") && !ItemKinds.isClipText(root.cur)

            AppIcon {
                anchors.fill: parent
                source: root.cur ? (root.cur.appIcon || "") : ""
                fallback: "image-missing"
                visible: root.cur && ((root.cur.appIcon || "") !== "")
            }
            MaterialIcon {
                anchors.centerIn: parent
                iconName: root.cur ? (root.cur.iconName || "circle") : "circle"
                size: 56
                color: Appearance.md3.primary
                visible: root.cur && ((root.cur.appIcon || "") === "") && ((root.cur.ch || "") === "")
            }
            StyledText {
                anchors.centerIn: parent
                text: root.cur ? (root.cur.ch || "") : ""
                font.pixelSize: 56
                visible: root.cur && ((root.cur.ch || "") !== "")
            }
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            // En clip-texto no hay cabecera: el cuerpo ya muestra
            // el texto completo (evita verlo dos veces).
            visible: !(root.cur && ItemKinds.isClipText(root.cur))
            text: root.cur ? (root.cur.title || "") : ""
            font.pixelSize: 14
            color: Appearance.md3.on_surface
        }
        // Texto del fichero (ficheros de texto): bloque monoespaciado con scroll
        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: 280
            visible: ItemKinds.hasTextPreview(root.cur) && root.previewText !== ""
            contentWidth: width
            contentHeight: previewDoc.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Text {
                id: previewDoc

                width: parent.width
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                text: {
                    if (root.previewText === "QSTEXT_TOO_BIG")
                        return root.fileTooLargeText;
                    return root.previewText;
                }
                font.family: Appearance.font.mono
                font.pixelSize: 11
                color: Appearance.md3.on_surface_variant
            }
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 6
            elide: Text.ElideRight
            // En clip-texto el cuerpo ya es el texto: sin pie duplicado.
            visible: !(root.cur && ItemKinds.isClipText(root.cur))
            text: {
                if (!root.cur)
                    return "";
                if (root.cur.kind === "clip" && !root.cur.isImage)
                    return (root.cur.fullText || root.cur.title) || "";
                return root.cur.sub || "";
            }
            font.pixelSize: 12
            color: Appearance.md3.on_surface_variant
        }
        // Texto del portapapeles (clip texto): bloque con scroll que
        // ocupa todo el alto libre. Muestra el decode completo en
        // cuanto llega; mientras tanto, la línea del listado.
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: ItemKinds.isClipText(root.cur)
            contentWidth: width
            contentHeight: clipDoc.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Text {
                id: clipDoc

                width: parent.width
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                text: root.clipText !== "" ? root.clipText : (root.cur ? ((root.cur.fullText || root.cur.title) || "") : "")
                font.pixelSize: 13
                color: Appearance.md3.on_surface
            }
        }
    }
}
