pragma Singleton
import Quickshell

Singleton {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property string pictures: Quickshell.env("XDG_PICTURES_DIR") || `${home}/Imágenes`
    readonly property string config: Quickshell.env("XDG_CONFIG_HOME") || `${home}/.config`
    readonly property string state: Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`
}
