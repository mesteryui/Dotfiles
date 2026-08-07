// --- AppLauncher ---
pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick.Layouts
import qs.Core
import qs.Primitives
import qs.Shared.Background

PanelWindow {
    id: launcher

    property bool launcherVisible: false
    visible: launcherVisible

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "transparent"
    exclusiveZone: -1

    // Clic fuera del panel central para cerrar
    MouseArea {
        anchors.fill: parent
        onClicked: launcher.launcherVisible = false
    }

    HyprlandFocusGrab {
        windows: [launcher]
        active: launcher.launcherVisible
        onCleared: Qt.callLater(() => launcher.launcherVisible = false)
    }

    function launchCurrent() {
        const item = appList.currentItem;
        if (item && item.modelData) {
            item.modelData.execute();
            launcher.launcherVisible = false;
        }
    }

    onLauncherVisibleChanged: {
        if (launcherVisible) {
            searchField.text = "";
            searchField.forceActiveFocus();
        }
    }

    WlrLayershell.keyboardFocus: launcher.launcherVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    IpcHandler {
        target: "launcher"
        function toggle() {
            launcher.launcherVisible = !launcher.launcherVisible;
        }
    }

    SurfaceBackground {
        id: background
        width: 480
        height: 560
        anchors.centerIn: parent
        color: Appearance.md3.surface
        radius: 28

        MouseArea {
            // Evita que el clic dentro del cuadro cierre el launcher
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            MaterialTextField {
                id: searchField
                placeholderText: "Buscar aplicaciones..."
                Layout.fillWidth: true
                selectedTextColor: Appearance.md3.on_primary
                selectionColor: Appearance.md3.primary
                focus: true
                

                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        launcher.launcherVisible = false;
                        event.accepted = true;
                        break;
                    case Qt.Key_Down:
                        appList.incrementCurrentIndex();
                        event.accepted = true;
                        break;
                    case Qt.Key_Up:
                        appList.decrementCurrentIndex();
                        event.accepted = true;
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        launcher.launchCurrent();
                        event.accepted = true;
                        break;
                    }
                }
            }

            // Pila contenedora para la lista y el estado vacío
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: appList
                    anchors.fill: parent
                    clip: true
                    spacing: 4
                    currentIndex: count > 0 ? 0 : -1
                    highlightMoveDuration: 100
                    keyNavigationEnabled: false

                    // Forzar que el primer elemento siempre quede seleccionado tras recalcular la lista
                    onCountChanged: {
                        if (count > 0 && currentIndex === -1)
                            currentIndex = 0;
                    }

                    model: ScriptModel {
                        values: {
                            const apps = DesktopEntries.applications.values;
                            const query = searchField.text.trim().toLowerCase();

                            if (query.length === 0)
                                return apps;

                            return apps.filter(e => e.name.toLowerCase().includes(query) 
                                               || (e.comment && e.comment.toLowerCase().includes(query)));
                        }
                    }

                    delegate: Rectangle {
                        id: entryDelegate
                        required property var modelData
                        required property int index

                        width: appList.width
                        height: 56
                        radius: 16
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 12

                            AppIcon {
                                implicitWidth: 32
                                implicitHeight: 32
                                source: entryDelegate.modelData.icon
                                fallback: "image-missing"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: entryDelegate.modelData.name
                                    font.pixelSize: 14
                                    color: Appearance.md3.on_surface
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: entryDelegate.modelData.comment
                                    font.pixelSize: 12
                                    color: Appearance.md3.on_surface_variant
                                    elide: Text.ElideRight
                                    visible: text.length > 0
                                }
                            }
                        }

                        Rectangle {
                            id: stateLayer
                            anchors.fill: parent
                            radius: parent.radius

                            property bool hovered: false
                            property bool pressed: false

                            color: Appearance.md3.on_surface
                            opacity: pressed ? 0.12
                                     : (hovered || entryDelegate.ListView.isCurrentItem) ? 0.08
                                     : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 100
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                stateLayer.hovered = true;
                                appList.currentIndex = entryDelegate.index; // Sincroniza la selección con el ratón
                            }
                            onExited: stateLayer.hovered = false
                            onPressed: stateLayer.pressed = true
                            onReleased: stateLayer.pressed = false
                            onClicked: {
                                entryDelegate.modelData.execute();
                                launcher.launcherVisible = false;
                            }
                        }
                    }
                }

                // --- ESTADO VACÍO (NO RESULTS) ---
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12
                    visible: appList.count === 0

                    IconImage {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 48
                        implicitHeight: 48
                        // Puedes usar un icono de freedesktop genérico o un SVG propio
                        source: Quickshell.iconPath("search-none-symbolic", true) 
                                || Quickshell.iconPath("edit-find-symbolic", true)
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No se encontraron aplicaciones"
                        font.pixelSize: 14
                        color: Appearance.md3.on_surface_variant
                    }
                }
            }
        }
    }
}