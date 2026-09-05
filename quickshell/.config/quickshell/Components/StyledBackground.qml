// StyledBackground.qml
// Thin wrapper de compatibilidad hacia SurfaceBackground.
// Mantiene la propiedad `content` original pero delega el fondo a SurfaceBackground.
// Todos los usos nuevos deben importar qs.Shared.Background y usar SurfaceBackground.
import qs.Shared.Background
import QtQuick

SurfaceBackground {
    id: root

    /// Compatibilidad: propiedad `content` original de StyledBackground.
    /// Asigna un Component que se instanciará centrado dentro del fondo.
    property Component content: null

    Loader {
        id: contentLoader

        anchors.centerIn: parent
        sourceComponent: root.content
    }
}