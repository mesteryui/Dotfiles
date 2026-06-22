import QtQuick
import qs.Core
import qs.Core.Services as Services
import qs.Primitives

// Contenido visual de la cabecera: icono, título y botón refresh.
// Sin fondos ni radius — eso es responsabilidad de UpdateListHeader.
Item {
    id: root

    Row {
        anchors {
            left: parent.left
            bottom: parent.bottom
            margins: 16
            bottomMargin: 12
        }
        spacing: 10

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            icon: Services.UpdatesTracking.failed   ? "warning"          :
                  Services.UpdatesTracking.checking ? "sync"             :
                                                      "system_update_alt"
            color: Services.UpdatesTracking.failed  ? Colors.md3.error
                                                    : Colors.md3.on_surface
            size: 20
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (Services.UpdatesTracking.failed)
                    return Services.I18nService.getTranslation("update.error");
                if (Services.UpdatesTracking.checking)
                    return Services.I18nService.getTranslation("update.checking");
                if (Services.UpdatesTracking.updateCount === 0)
                    return Services.I18nService.getTranslation("update.up_to_date");
                const key = Services.UpdatesTracking.updateCount === 1
                    ? "update.package_singular"
                    : "update.package_plural";
                return Services.UpdatesTracking.updateCount + " "
                     + Services.I18nService.getTranslation(key);
            }
            font.family: Services.ConfigService.configs.appearence.fontSans
            font.pixelSize: 15
            font.weight: Font.Bold
            color: Services.UpdatesTracking.failed ? Colors.md3.error
                                                   : Colors.md3.on_surface
        }
    }

    ButtonIcon {
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: 12
        }
        iconName: "refresh"
        iconSize: 18
        enabled: !Services.UpdatesTracking.checking && !Services.UpdatesTracking.updating
        onClicked: Services.UpdatesTracking.checkNow()
    }
}
