// CalendarPopupWindow — Wrapper
// Gestiona estado del calendario y ensambla Background + Content.

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import qs.Core
import qs.Core.Services as Services
import qs.Shared.Background

PopupWindow {
    id: root
    color: "transparent"
    visible: false
    implicitWidth: 320
    implicitHeight: 400
    grabFocus: true

    TransformWatcher {
        id: watcher
        a: root.open ? root.triggerItem : null
        b: root.contentItem
        onTransformChanged: if (root.open) root.anchor.updateAnchor()
    }

    // ── Estado ────────────────────────────────────────────────
    property date currentDate:  new Date()
    property int  currentMonth: currentDate.getMonth()
    property int  currentYear:  currentDate.getFullYear()
    property int  selectedDay:  -1

    readonly property var currentLocale: Services.I18nService.locale

    // ── Ciclo de vida ─────────────────────────────────────────
    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: Qt.callLater(() => root.visible = false)
    }

    // ── Background ────────────────────────────────────────────
    MultiEffect {
        source: bg
        anchors.fill: bg
        shadowEnabled: true
        shadowColor: Appearance.md3.shadow
        shadowBlur: 0.85
        shadowVerticalOffset: 6
        shadowHorizontalOffset: 0
        blurMax: 32
        shadowOpacity: 0.18
        z: -1
    }

    PopupBackground {
        id: bg
        anchors.fill: parent
    }

    // ── Content ───────────────────────────────────────────────
    CalendarContent {
        anchors {
            fill: parent
            margins: 16
        }

        currentMonth: root.currentMonth
        currentYear:  root.currentYear
        selectedDay:  root.selectedDay
        currentLocale: root.currentLocale

        onPrevMonthRequested: {
            if (root.currentMonth === 0) { root.currentMonth = 11; root.currentYear-- }
            else root.currentMonth--
            root.selectedDay = -1
        }
        onNextMonthRequested: {
            if (root.currentMonth === 11) { root.currentMonth = 0; root.currentYear++ }
            else root.currentMonth++
            root.selectedDay = -1
        }
        onDaySelected: (day) => root.selectedDay = day
    }
}
