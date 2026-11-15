pragma Singleton
pragma ComponentBehavior: Bound

import qs.Core.Services
import qs.Core.Modules
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property alias md3: jsonAdapter.md3
    property alias base16: jsonAdapter.base16
    property alias palette: jsonAdapter.palette

    readonly property Shape shape: Shape {}
    readonly property Border border: Border {}
    readonly property FontConfig font: FontConfig {}
    readonly property State state: State {}
    readonly property TypeScale typeScale: TypeScale {}
    readonly property Motion motion: Motion {}
    readonly property Spacing spacing: Spacing {}

    FileView {
        path: Directories.state + "/quickshell/generated/colors.json"
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: jsonAdapter

            readonly property Md3 md3: Md3 {}
            readonly property Base16 base16: Base16 {}
            readonly property Palette palette: Palette {}
        }
    }

    // Escala de radios: de `micro` (casi recto) a `huge` (paneles grandes).
    // Los nombres indican el tamaño relativo y siempre ascienden:
    // micro < extraSmall < small < medium < large < extraLarge < huge.
    // El orden importa: cada token se usa para su nivel de contenedor, no
    // como valor decorativo suelto. `screenRounding` sigue a `extraLarge`.
    component Shape: QtObject {
        property int micro: 2
        property int extraSmall: 4
        property int small: 8
        property int medium: 12
        property int large: 17
        property int extraLarge: 23
        property int huge: 30
        property int full: 9999
        property int screenRounding: extraLarge
        property int windowRounding: 18
        // Marco de pantalla de la barra en los modos "hug" (`full_hug` y
        // `partial_hug`): grosor de las bandas del color de la barra que
        // bordean la pantalla. El radio de sus esquinas es `screenRounding`.
        // Consumidores: Bar/ScreenRounding.qml (hug) y Bar.qml (notch, radio
        // exterior; el interior del notch usa `medium`).
        property int screenBorder: 14
        // Radio de tarjeta/popup estándar (caelestia `largeIncreased`): entre
        // `large` y `extraLarge`, para menús y paneles compactos. No sustituye
        // a `huge` en los paneles grandes.
        property int card: 20
    }

    // Contrato de bordes (caelestia/end-4): un trazo hairline de 1px en las
    // superficies flotantes (barra, popups, tarjetas elevadas), nunca en cada
    // elemento interno; 2px solo para foco/selección. El color de reposo no
    // usa `outline_variant` a plena intensidad: se mezcla con la superficie
    // al 40% (como `colLayer0Border` de end-4) para que el borde defina sin
    // competir con el contenido. `color` es el valor por defecto sobre
    // `surface`; para otras superficies usar `subtleOn(colorDeFondo)`.
    component Border: QtObject {
        property int width: 1
        property int focusWidth: 2
        readonly property color color: subtleOn(root.md3.surface)
        readonly property color strong: root.md3.outline
        readonly property color focus: root.md3.primary
        readonly property color selected: root.md3.primary
        readonly property color error: root.md3.error
        // Separadores de 1px dentro de paneles/listas (no son bordes de
        // superficie): mismo trazo que los divisores de sección.
        readonly property color divider: Qt.alpha(root.md3.outline_variant, 0.4)

        function subtleOn(baseColor) {
            return Qt.tint(baseColor, Qt.alpha(root.md3.outline_variant, 0.4));
        }
    }

    // Opacidades decorativas (textos atenuados, placeholders): un solo
    // sitio en vez de literales 0.3/0.5/0.7/0.8 dispersos.
    // (Objeto anónimo en vez de `component`: el registro inline fallaba
    // aquí con "is not a type".)
    readonly property QtObject opacity: QtObject {
        property real hint: 0.7
        property real hintStrong: 0.8
        property real faint: 0.5
        property real ghost: 0.3
    }

    // Opacidades de estado M3 (state layers + deshabilitado): un solo sitio
    // para hover (8%), pressed (12%) y contenido deshabilitado (38%).
    component State: QtObject {
        property real hovered: 0.08
        property real pressed: 0.12
        property real disabled: 0.38
    }

    // Niveles de elevation M3 (sombra tonal): un solo mando para
    // opacidad/blur/desplazamiento. Valores heredados tal cual (el avatar
    // baja de .24 a .22 al entrar en sheet, resto pixel-idéntico).
    // password/toast/iconButton/deco-empty conservan valores propios por
    // ser casos especiales (documentado donde aplica).
    component Elevation: QtObject {
        property real opacity: 0.18
        property real blur: 0.85
        property int offsetY: 6
    }

    readonly property Elevation elevation1: Elevation {
        opacity: 0.08
        blur: 0.4
        offsetY: 2
    }   // cards

    readonly property Elevation elevation2: Elevation {
        opacity: 0.18
        blur: 0.85
        offsetY: 6
    }  // popups

    readonly property Elevation elevation3: Elevation {
        opacity: 0.18
        blur: 0.5
        offsetY: 2
    }   // media

    readonly property Elevation elevation4: Elevation {
        opacity: 0.20
        blur: 0.8
        offsetY: 4
    }   // dialogs

    readonly property Elevation elevation5: Elevation {
        opacity: 0.22
        blur: 0.9
        offsetY: 3
    }   // sheets

    // Escala de spacing (márgenes y separaciones): extraSmall 4, small 8,
    // medium 12, large 16 y extraLarge 24. La misma base que comparten
    // caelestia (`Tokens.spacing`) y end-4 en sus contenedores. Un solo mando
    // para la densidad de la shell: los huecos de 2/3 que quedan en
    // componentes concretos son micro-ajustes locales, no la escala.
    component Spacing: QtObject {
        property int extraSmall: 4
        property int small: 8
        property int medium: 12
        property int large: 16
        property int extraLarge: 24
    }
    // Escala de tipos M3 (nombres spec). Los roles de icono/display usan
    // `font.pixelSize` (large/larger/huge/massive), fuera de la escala de texto.
    component TypeScale: QtObject {
        property int labelXSmall: 9   // micro (badges, timestamps)
        property int labelSmall: 11   // spec 11
        property int labelMedium: 12  // spec 12
        property int bodySmall: 12    // spec 12
        property int bodyMedium: 14   // spec 14
        property int bodyLarge: 16    // spec 16
        property int titleSmall: 14   // spec 14
        property int titleMedium: 16  // spec 16
        property int titleLarge: 19   // spec 22 (larger; expresivo)
        property int headlineSmall: 22 // spec 24 (huge; expresivo)
    }

    // Presets físicos (M3 Expressive: esquema Expressive para entradas
    // hero, Standard para micro-interacciones; spatial con overshoot,
    // effects —color/opacity— siempre lineales, sin overshoot).
    // Rangos según doc Qt (doc.qt.io/qt-6/qml-qtquick-springanimation):
    // spring 0-5, damping 0-1 (¡el setter recorta a 1.0: valores mayores
    // divergen y rompen la UI!). Integración Euler semi-implícita a 16ms:
    // damping alto = menos rebote (manda el fuente qtdeclarative:
    // velocity += spring*diff - damping*velocity).
    // Epsilon según doc: 0.005 para scale, 0.25 para píxeles.
    // Uso: Behavior on scale { SpringAnimation {
    //   spring: Appearance.motion.springSnappy.spring; ... } }
    component SpringParams: QtObject {
        property real spring: 2.0
        property real damping: 0.3
        property real mass: 1.0
        property real epsilon: 0.005
    }

    // Esquema de motion M3 (duraciones fijas; animaciones sobrias por
    // diseño, sin interruptor de movimiento reducido). Nombres por velocidad,
    // de `instant` a `slowest`; entre paréntesis, el rol M3 equivalente.
    component Motion: QtObject {
        property int instant: 50      // short1
        property int veryFast: 100    // short2
        property int fast: 150        // short3
        property int normal: 200      // short4
        property int relaxed: 250     // medium1
        property int slow: 300        // medium2
        property int verySlow: 350    // medium3
        property int slowest: 450     // long1
        // Curvas M3 para Easing.Bezier (easing.bezierCurve).
        property var standard: [0.2, 0.0, 0.0, 1.0]
        property var emphasized: [0.05, 0.7, 0.1, 1.0]

        // Suave Standard (paneles, hovers): ~0.35s, overshoot <1%.
        readonly property SpringParams springSoft: SpringParams {
            spring: 2.0
            damping: 0.32
            mass: 1.0
            epsilon: 0.005
        }
        // Entradas Expressive (aperturas): un overshoot ~10%, ~0.45s.
        readonly property SpringParams springBouncy: SpringParams {
            spring: 3.5
            damping: 0.28
            mass: 1.0
            epsilon: 0.005
        }
        // Micro-interacciones (botones, switches): ~0.29s, overshoot ~1.5%.
        readonly property SpringParams springSnappy: SpringParams {
            spring: 5.0
            damping: 0.45
            mass: 1.0
            epsilon: 0.005
        }
        // Tamaños en layout: casi crítico, sin rebote visible, ~0.25s.
        readonly property SpringParams springSize: SpringParams {
            spring: 4.0
            damping: 0.5
            mass: 1.0
            epsilon: 0.25
        }
    }

    component FontConfig: QtObject {

        readonly property string sans: ConfigService.configs.appearance.fontSans ?? "Google Sans Flex"

        readonly property string mono: ConfigService.configs.appearance.monospace ?? "JetBrainsMono Nerd Font"

        readonly property string reading: ConfigService.configs.appearance.reading ?? "Google Sans Flex"

        readonly property string expressive: ConfigService.configs.appearance.expressive ?? "Google Sans Flex"

        property string iconMaterial: "Material Symbols Rounded"

        readonly property VariableAxes variableAxes: VariableAxes {}

        readonly property PixelSize pixelSize: PixelSize {}
    }

    component VariableAxes: QtObject {
        property var main: ({
                                "wght": 490,
                                "wdth": 100
                            })
        property var numbers: ({
                                   "wght": 450
                               })
        property var title: ({ // Slightly bold weight for title
                                 "wght": 550 // Weight (Lowered to compensate for increased grade)
                             })
    }

    // Tamaños de icono y texto de display (no son roles M3: para texto usa
    // `typeScale`). Escala ascendente: large < larger < huge < massive.
    component PixelSize: QtObject {
        property int large: 17
        property int larger: 19
        property int huge: 22
        property int massive: 23
    }

    component Md3: JsonObject {
        property string background: "transparent"
        property string error: "transparent"
        property string error_container: "transparent"
        property string inverse_on_surface: "transparent"
        property string inverse_primary: "transparent"
        property string inverse_surface: "transparent"
        property string on_background: "transparent"
        property string on_error: "transparent"
        property string on_error_container: "transparent"
        property string on_primary: "transparent"
        property string on_primary_container: "transparent"
        property string on_primary_fixed: "transparent"
        property string on_primary_fixed_variant: "transparent"
        property string on_secondary: "transparent"
        property string on_secondary_container: "transparent"
        property string on_secondary_fixed: "transparent"
        property string on_secondary_fixed_variant: "transparent"
        property string on_surface: "transparent"
        property string on_surface_variant: "transparent"
        property string on_tertiary: "transparent"
        property string on_tertiary_container: "transparent"
        property string on_tertiary_fixed: "transparent"
        property string on_tertiary_fixed_variant: "transparent"
        property string outline: "transparent"
        property string outline_variant: "transparent"
        property string primary: "transparent"
        property string primary_container: "transparent"
        property string primary_fixed: "transparent"
        property string primary_fixed_dim: "transparent"
        property string scrim: "transparent"
        property string secondary: "transparent"
        property string secondary_container: "transparent"
        property string secondary_fixed: "transparent"
        property string secondary_fixed_dim: "transparent"
        property string shadow: "transparent"
        property string surface: "transparent"
        property string surface_bright: "transparent"
        property string surface_container: "transparent"
        property string surface_container_high: "transparent"
        property string surface_container_highest: "transparent"
        property string surface_container_low: "transparent"
        property string surface_container_lowest: "transparent"
        property string surface_dim: "transparent"
        property string surface_tint: "transparent"
        property string surface_variant: "transparent"
        property string tertiary: "transparent"
        property string tertiary_container: "transparent"
        property string tertiary_fixed: "transparent"
        property string tertiary_fixed_dim: "transparent"
    }

    component Palette: JsonObject {
        property string error0: "transparent"
        property string error5: "transparent"
        property string error10: "transparent"
        property string error15: "transparent"
        property string error20: "transparent"
        property string error25: "transparent"
        property string error30: "transparent"
        property string error35: "transparent"
        property string error40: "transparent"
        property string error50: "transparent"
        property string error60: "transparent"
        property string error70: "transparent"
        property string error80: "transparent"
        property string error90: "transparent"
        property string error95: "transparent"
        property string error98: "transparent"
        property string error99: "transparent"
        property string error100: "transparent"

        property string neutral0: "transparent"
        property string neutral5: "transparent"
        property string neutral10: "transparent"
        property string neutral15: "transparent"
        property string neutral20: "transparent"
        property string neutral25: "transparent"
        property string neutral30: "transparent"
        property string neutral35: "transparent"
        property string neutral40: "transparent"
        property string neutral50: "transparent"
        property string neutral60: "transparent"
        property string neutral70: "transparent"
        property string neutral80: "transparent"
        property string neutral90: "transparent"
        property string neutral95: "transparent"
        property string neutral98: "transparent"
        property string neutral99: "transparent"
        property string neutral100: "transparent"

        property string neutral_variant0: "transparent"
        property string neutral_variant5: "transparent"
        property string neutral_variant10: "transparent"
        property string neutral_variant15: "transparent"
        property string neutral_variant20: "transparent"
        property string neutral_variant25: "transparent"
        property string neutral_variant30: "transparent"
        property string neutral_variant35: "transparent"
        property string neutral_variant40: "transparent"
        property string neutral_variant50: "transparent"
        property string neutral_variant60: "transparent"
        property string neutral_variant70: "transparent"
        property string neutral_variant80: "transparent"
        property string neutral_variant90: "transparent"
        property string neutral_variant95: "transparent"
        property string neutral_variant98: "transparent"
        property string neutral_variant99: "transparent"
        property string neutral_variant100: "transparent"

        property string primary0: "transparent"
        property string primary5: "transparent"
        property string primary10: "transparent"
        property string primary15: "transparent"
        property string primary20: "transparent"
        property string primary25: "transparent"
        property string primary30: "transparent"
        property string primary35: "transparent"
        property string primary40: "transparent"
        property string primary50: "transparent"
        property string primary60: "transparent"
        property string primary70: "transparent"
        property string primary80: "transparent"
        property string primary90: "transparent"
        property string primary95: "transparent"
        property string primary98: "transparent"
        property string primary99: "transparent"
        property string primary100: "transparent"

        property string secondary0: "transparent"
        property string secondary5: "transparent"
        property string secondary10: "transparent"
        property string secondary15: "transparent"
        property string secondary20: "transparent"
        property string secondary25: "transparent"
        property string secondary30: "transparent"
        property string secondary35: "transparent"
        property string secondary40: "transparent"
        property string secondary50: "transparent"
        property string secondary60: "transparent"
        property string secondary70: "transparent"
        property string secondary80: "transparent"
        property string secondary90: "transparent"
        property string secondary95: "transparent"
        property string secondary98: "transparent"
        property string secondary99: "transparent"
        property string secondary100: "transparent"

        property string tertiary0: "transparent"
        property string tertiary5: "transparent"
        property string tertiary10: "transparent"
        property string tertiary15: "transparent"
        property string tertiary20: "transparent"
        property string tertiary25: "transparent"
        property string tertiary30: "transparent"
        property string tertiary35: "transparent"
        property string tertiary40: "transparent"
        property string tertiary50: "transparent"
        property string tertiary60: "transparent"
        property string tertiary70: "transparent"
        property string tertiary80: "transparent"
        property string tertiary90: "transparent"
        property string tertiary95: "transparent"
        property string tertiary98: "transparent"
        property string tertiary99: "transparent"
        property string tertiary100: "transparent"
    }

    component Base16: JsonObject {
        property string base00: "transparent"
        property string base01: "transparent"
        property string base02: "transparent"
        property string base03: "transparent"
        property string base04: "transparent"
        property string base05: "transparent"
        property string base06: "transparent"
        property string base07: "transparent"
        property string base08: "transparent"
        property string base09: "transparent"
        property string base0a: "transparent"
        property string base0b: "transparent"
        property string base0c: "transparent"
        property string base0d: "transparent"
        property string base0e: "transparent"
        property string base0f: "transparent"
    }
}
