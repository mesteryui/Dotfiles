import QtQuick.Controls
import QtQuick.Controls.Material
import qs.Core

ProgressBar {
    width: parent.width
    Material.accent: Colors.md3.primary
    Material.background: Colors.md3.background
    Material.foreground: Colors.md3.on_background
    Material.roundedScale: Material.FullScale
}