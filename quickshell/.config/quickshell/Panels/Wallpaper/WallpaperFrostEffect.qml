import QtQuick
import QtQuick.Effects

// Efecto aislado del deck frost. Se usa como `layer.effect` del contenedor
// de las imágenes (ver WallpaperLayerScreen), así que borrar este archivo y
// las dos líneas `layer` de wallpaperPlane deja el wallpaper intacto.
//
// autoPaddingEnabled: false mantiene el FBO del tamaño de la pantalla; el
// blur no necesita padding porque las imágenes ya cubren el fondo completo.
MultiEffect {
    id: root

    property real amount: 0
    property int maxRadius: 24

    blurEnabled: true
    blur: root.amount
    blurMax: root.maxRadius
    autoPaddingEnabled: false
}
