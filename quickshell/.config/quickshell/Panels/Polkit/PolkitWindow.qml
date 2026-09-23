import qs.Shared.Background
import qs.Core.Services
import qs.Core
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    // LazyLoader: el diálogo se incuba en background y se cachea. Como ya
    // no se destruye al cerrarse, el visible va atado al servicio.
    LazyLoader {
        loading: PolkitService.active
        component: PanelWindow {
            id: root

            visible: PolkitService.active

            readonly property bool usePasswordChars: !PolkitService.flow?.responseVisible ?? true

            // Full-screen overlay, above everything, grabs keyboard while active
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:polkitDialog"

            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Connections {
                target: PolkitService

                function onInteractionAvailableChanged() {
                    if (!PolkitService.interactionAvailable)
                        return;
                    content.clearText();
                    content.forceFocus();
                }
            }

            PolkitContent {
                id: content

                usePasswordChars: root.usePasswordChars
                cleanMessage: PolkitService.cleanMessage
                cleanPrompt: PolkitService.cleanPrompt
                interactionAvailable: PolkitService.interactionAvailable

                onClosed: {
                    content.clearText();
                    PolkitService.cancel();
                }
                onSubmit: text => {
                    PolkitService.submit(text);
                }
            }

            SurfaceBackground {
                anchors.fill: parent
                radius: 0
                color: Qt.alpha(Appearance.md3.surface, 0.5)
                z: -1
            }
        }
    }
}
