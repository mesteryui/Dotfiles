pragma Singleton

import qs.Core.Services
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core.Modules

Singleton {
    id: root

    property alias md3: jsonAdapter.md3
    property alias base16: jsonAdapter.base16
    property alias palette: jsonAdapter.palette

    readonly property Shape shape: Shape {}
    readonly property FontConfig font: FontConfig {}
    readonly property State state: State {}
    readonly property TypeScale typeScale: TypeScale {}
    readonly property Motion motion: Motion {}
    readonly property Spacing spacing: Spacing {}

    // Reducir movimiento: las duraciones del esquema colapsan a 1ms (los
    // bucles infinitos —indeterminado, respiraciones— se apagan donde viven).
    readonly property bool reduceMotion: ConfigService.configs.appearance.reduceMotion ?? false

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

    component Shape: QtObject {
        property int unsharpen: 2
        property int extraSmall: 4
        property int unsharpenmore: 6
        property int verysmall: 8
        property int small: 12
        property int normal: 17
        property int large: 23
        property int verylarge: 30
        property int full: 9999
        property int screenRounding: large
        property int windowRounding: 18
        // Radio de tarjeta estándar de la shell (banners, M3Cards con override,
        // menús, paneles). Unifica los `radius: 20` literales antes dispersos.
        property int card: 20
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
    readonly property Elevation elevation1: Elevation { opacity: 0.08; blur: 0.4; offsetY: 2 }   // cards
    readonly property Elevation elevation2: Elevation { opacity: 0.18; blur: 0.85; offsetY: 6 }  // popups
    readonly property Elevation elevation3: Elevation { opacity: 0.18; blur: 0.5; offsetY: 2 }   // media
    readonly property Elevation elevation4: Elevation { opacity: 0.20; blur: 0.8; offsetY: 4 }   // dialogs
    readonly property Elevation elevation5: Elevation { opacity: 0.22; blur: 0.9; offsetY: 3 }   // sheets

    // Escala de spacing M3 (márgenes y separaciones): un solo mando para
    // la densidad de la shell.
    component Spacing: QtObject {
        property int xs: 4
        property int s: 8
        property int m: 12
        property int l: 16
        property int xl: 24
    }
    // Escala de tipos M3 (nombres spec; los roles de icono/display usan
    // large/larger/huge/hugeass tal cual, fuera de la escala de texto).
    component TypeScale: QtObject {
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

    // Esquema de motion M3 (duraciones; los easings se migran aparte).
    // Con reduceMotion colapsan a 1ms (los bucles se apagan donde viven).
    component Motion: QtObject {
        readonly property bool reduced: ConfigService.configs.appearance.reduceMotion ?? false
        property int short1: reduced ? 1 : 50
        property int short2: reduced ? 1 : 100
        property int short3: reduced ? 1 : 150
        property int short4: reduced ? 1 : 200
        property int medium1: reduced ? 1 : 250
        property int medium2: reduced ? 1 : 300
        property int medium3: reduced ? 1 : 350
        property int long1: reduced ? 1 : 450
        // Curvas M3 para Easing.Bezier (easing.bezierCurve).
        property var standard: [0.2, 0.0, 0.0, 1.0]
        property var emphasized: [0.05, 0.7, 0.1, 1.0]
    }

    component FontConfig: QtObject {

        readonly property string sans: ConfigService.configs.appearance.fontSans ?? "Google Sans Flex"

        readonly property string mono: ConfigService.configs.appearance.monospace ?? "JetBrains Mono Nerd Font"

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

    component PixelSize: QtObject {
        property int smallest: 11
        property int smaller: 12
        property int smallie: 14
        property int small: 14
        property int normal: 16
        // large/larger/huge/hugeass dimensionan iconos y display expresivo:
        // se conservan a propósito (17/19/22/23), no son roles de texto M3.
        property int large: 17
        property int larger: 19
        property int huge: 22
        property int hugeass: 23
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
