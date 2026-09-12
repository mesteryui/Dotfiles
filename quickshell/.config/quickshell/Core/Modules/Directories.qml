import Quickshell

Singleton {
    property string XDG_CONFIG_HOME: Quickshell.env("XDG_CONFIG_HOME") || "/home/oscar/.config"
}
