import qs.Core
import qs.Core.Services as Services
import qs.Primitives
import QtQuick

MaterialIcon {
    id: root

    property bool active: Services.IdleInhibitedService.inhibited

    size: Appearance.font.pixelSize.larger
    fill: root.active ? 1 : 0
    color: root.active ? Appearance.md3.primary : Appearance.md3.on_surface
    icon: "local_cafe"
}
