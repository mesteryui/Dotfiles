// LauncherSearchBar — barra de búsqueda M3 del launcher.
// Extraído de AppLauncher.qml. `controller` es el PanelWindow del launcher,
// `scopeObj` su Scope y `resultView` el ResultList; `field` expone el TextField.
pragma ComponentBehavior: Bound
import qs.Core
import qs.Core.Modules
import qs.Core.Services as Services
import qs.Primitives
import QtQuick
import QtQuick.Layouts
import M3Shapes

Rectangle {
    id: root

    implicitHeight: 56
    radius: Appearance.shape.full
    color: Appearance.md3.surface_container_high

    property var controller
    property var scopeObj
    property var resultView
    property alias field: searchField

    // Rota de modo (venía de AppLauncher; solo lo usa Tab en este campo).
    function cycleMode(dir) {
        const order = controller.modes.map(m => m.modeId);
        let i = order.indexOf(controller.activeMode);
        i = (i + dir + order.length) % order.length;
        if (order[i] === "system") {
            scopeObj.forcedMode = "";
            controller.goSection("main");
            return;
        }
        const p = controller.prefixOf(order[i]);
        scopeObj.forcedMode = "";
        field.text = p;
        if (order[i] === "clip")
            Services.ClipboardService.refresh();
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 6
        spacing: Appearance.spacing.xs

        // Hero expresivo: morfea con el modo activo.
        Item {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            Layout.alignment: Qt.AlignVCenter

            MaterialShape {
                anchors.fill: parent
                shape: controller.modeShape(controller.activeMode)
                animationDuration: 350
                color: Appearance.md3.primary_container

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: controller.modeIcon(controller.activeMode)
                    size: Appearance.font.pixelSize.large
                    color: Appearance.md3.on_primary_container
                }
            }
        }

        MaterialTextField {
            id: searchField


            Layout.fillWidth: true
            Layout.fillHeight: true
            // Sin borde: el contenedor ya es la search bar.
            background: Rectangle {
                color: "transparent"
            }
            // Spec search supporting-text: on-surface-variant
            // (el primitivo usa outline, correcto con borde).
            placeholderTextColor: Appearance.md3.on_surface_variant
            verticalAlignment: TextInput.AlignVCenter
            // TextField ya expone rol EditableText; el nombre sigue
            // al placeholder del modo activo.
            Accessible.name: searchField.placeholderText
        selectedTextColor: Appearance.md3.on_primary
        selectionColor: Appearance.md3.primary
        focus: true
    placeholderText: {
        switch (controller.activeMode) {
        case "system": return controller.tr("controller.placeholder_system", "Sistema… (> para este modo)");
        case "files": return controller.tr("controller.placeholder_files", "Archivos en $HOME…");
        case "web": return controller.tr("controller.placeholder_web", "Buscar en DuckDuckGo…");
        case "emoji": return controller.tr("controller.placeholder_emoji", "Emojis y símbolos… (g:grupo · Ctrl+Mayús+F favorito)");
        case "calc": return controller.tr("controller.placeholder_calc", "Calculadora… ej: 45*1.21");
        case "clip": return controller.tr("controller.placeholder_clipboard", "Portapapeles (cliphist)…");
        default: return controller.tr("controller.placeholder_all", "Buscar aplicaciones…");
        }
    }

    // Sin carácter de menú → volver al menú por defecto.
    onTextChanged: {
        // Escribir vuelve a modo texto (flechas al cursor).
        controller.navResults = false;
        if (scopeObj.forcedMode !== "" && !text.startsWith(controller.prefixOf(scopeObj.forcedMode)))
            scopeObj.forcedMode = "";
    }

    Keys.onPressed: event => {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const shift = event.modifiers & Qt.ShiftModifier;
        if (ctrl && shift && event.key === Qt.Key_P) {
            // Fija/quita la app seleccionada (solo modo todo).
            // Va antes del Ctrl+P de navegación: lleva Shift.
            controller.togglePinCurrent();
            event.accepted = true;
            return;
        }
        if (ctrl && shift && event.key === Qt.Key_F) {
            // Marca/desmarca el emoji seleccionado como favorito.
            controller.toggleFavCurrent();
            event.accepted = true;
            return;
        }
        if (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N)) {
            // En cuadrícula: abajo (una fila); en lista: siguiente.
            controller.navResults = true;
            if (resultView.isGrid)
                resultView.moveGrid(0, 1);
            else
                resultView.moveSelection(1);
            event.accepted = true;
            return;
        }
        if (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P)) {
            // En cuadrícula: arriba (una fila); en lista: anterior.
            controller.navResults = true;
            if (resultView.isGrid)
                resultView.moveGrid(0, -1);
            else
                resultView.moveSelection(-1);
            event.accepted = true;
            return;
        }
        if (ctrl && event.key === Qt.Key_F) {
            // En cuadrícula: derecha. En lista se deja pasar
            // al campo (mover cursor).
            if (resultView.isGrid) {
                controller.navResults = true;
                resultView.moveGrid(1, 0);
                event.accepted = true;
                return;
            }
        }
        if (ctrl && event.key === Qt.Key_B) {
            // En cuadrícula: izquierda. En lista, al campo.
            if (resultView.isGrid) {
                controller.navResults = true;
                resultView.moveGrid(-1, 0);
                event.accepted = true;
                return;
            }
        }
        switch (event.key) {
        case Qt.Key_Escape:
            // ESC sale del menú directamente.
            scopeObj.shown = false;
            event.accepted = true;
            break;
        case Qt.Key_Left:
            // Navegando: siempre a resultados. Escribiendo: solo
            // al borde izquierdo; si no, el campo mueve el cursor.
            // En lista, siempre al campo.
            if (resultView.isGrid && (controller.navResults || (searchField.cursorPosition === 0 && searchField.selectedText === ""))) {
                controller.navResults = true;
                resultView.moveGrid(-1, 0);
                event.accepted = true;
            }
            break;
        case Qt.Key_Right:
            // Simétrico al borde derecho.
            if (resultView.isGrid && (controller.navResults || (searchField.cursorPosition >= searchField.length && searchField.selectedText === ""))) {
                controller.navResults = true;
                resultView.moveGrid(1, 0);
                event.accepted = true;
            }
            break;
        case Qt.Key_Down:
            controller.navResults = true;
            if (resultView.isGrid)
                resultView.moveGrid(0, 1);
            else
                resultView.moveSelection(1);
            event.accepted = true;
            break;
        case Qt.Key_Up:
            controller.navResults = true;
            if (resultView.isGrid)
                resultView.moveGrid(0, -1);
            else
                resultView.moveSelection(-1);
            event.accepted = true;
            break;
        case Qt.Key_Tab:
            // Rota de modo
            cycleMode(event.modifiers & Qt.ShiftModifier ? -1 : 1);
            event.accepted = true;
            break;
        case Qt.Key_Backspace:
            // En modo sistema con query vacía: subir de sección.
            if (controller.activeMode === "system" && controller.query === "") {
                const parent = controller.systemParentSection();
                if (parent !== "") {
                    controller.goSection(parent);
                    event.accepted = true;
                }
            }
            break;
        case Qt.Key_Delete:
            if (controller.activeMode === "clip") {
                const d = resultView.itemAt(resultView.currentIndex);
                if (d && d.cid)
                    Services.ClipboardService.deleteEntry(d.cid);
                event.accepted = true;
            }
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            controller.activateCurrent();
            event.accepted = true;
            break;
        }
    }
}

// Trailing M3 (spec Search): limpiar texto cuando hay.
ButtonIcon {
    Layout.alignment: Qt.AlignVCenter
    iconName: "close"
    iconSize: 20
    iconColor: Appearance.md3.on_surface_variant
    visible: searchField.text !== ""
    onClicked: {
        searchField.text = "";
        searchField.forceActiveFocus();
    }
}
}
}
