import qs.Primitives
import qs.Core
import qs.Core.Services
MaterialIcon {
    id: networkIcon
    size: 20
    color: Colors.md3.on_surface
    icon: NetworkService.materialIconBySignal
}