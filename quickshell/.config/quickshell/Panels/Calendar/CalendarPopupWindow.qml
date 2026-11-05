// CalendarPopupWindow — Wrapper
// Gestiona estado del calendario y ensambla Background + Content.

import qs.Core
import qs.Core.Services as Services
import qs.Shared.Background
import qs.Primitives
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland

BarPopupWindow {
    id: root

    implicitWidth: 320
    implicitHeight: 400
    grabFocus: true

    // Color sólido del wrapper: se ve alrededor del fondo redondeado
    // (perímetro exterior de las esquinas del rectángulo con radius).
    // El wrapper no es transparente.

    // ── Estado ────────────────────────────────────────────────
    property date currentDate: new Date()

    property int currentMonth: currentDate.getMonth()

    property int currentYear: currentDate.getFullYear()

    property int selectedDay: -1

    readonly property var currentLocale: Services.I18nService.locale

    // ── Ciclo de vida ─────────────────────────────────────────
    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: Qt.callLater(() => root.visible = false)
    }

    // ── Background ────────────────────────────────────────────
    PopupBackground {
        id: bg

        anchors.fill: parent
        surfaceRadius: Appearance.shape.card
        baseColor: Appearance.md3.surface
        // Sin borde interno: el borde del fondo es el perímetro visible
        // del rectángulo redondeado contra el wrapper transparente.
        // Un borde como hijo interno de PopupBackground queda tapado por
        // el Content (hermano pintado después), así que no tiene sentido.
        showBorder: true
    }

    // Sombra: source se asigna de forma declarativa para evitar warning
    // "ShaderEffect: 'source' does not have a matching property" del primer frame.
    // bg es PopupBackground (tiene layer.enabled), así que su textura está lista.


    // ── Content ───────────────────────────────────────────────
    CalendarContent {
        anchors.fill: bg
        anchors.margins: Appearance.spacing.large

        currentMonth: root.currentMonth
        currentYear: root.currentYear
        selectedDay: root.selectedDay
        currentLocale: root.currentLocale

        onPrevMonthRequested: {
            if (root.currentMonth === 0) {
                root.currentMonth = 11;
                root.currentYear--;
            } else
                root.currentMonth--;
            root.selectedDay = -1;
        }
        onNextMonthRequested: {
            if (root.currentMonth === 11) {
                root.currentMonth = 0;
                root.currentYear++;
            } else
                root.currentMonth++;
            root.selectedDay = -1;
        }
        onDaySelected: day => root.selectedDay = day
    }
}
