// BarBackground.qml
// Thin wrapper de compatibilidad hacia SurfaceBackground.
// Mantiene el mismo API público para no romper ningún import existente en Bar/.
// Todos los usos nuevos deben importar qs.Shared.Background y usar SurfaceBackground.
import qs.Shared.Background
import QtQuick

SurfaceBackground {
    id: root
}
