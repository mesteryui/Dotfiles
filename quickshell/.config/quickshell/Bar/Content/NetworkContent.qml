import qs.Primitives
import qs.Core
import qs.Core.Services
MaterialIcon {
    id: networkIcon
    size: Appearance.font.pixelSize.larger
    color: Appearance.md3.on_surface
    icon: NetworkService.materialIconBySignal
}