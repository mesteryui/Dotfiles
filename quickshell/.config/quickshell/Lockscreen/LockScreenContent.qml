import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Widgets
import qs.Core
import qs.Primitives
Item {
    ColumnLayout {
        ClippingRectangle {
            Image {

            }
        }
        StyledTextArea {
            echoMode: TextInput.Password
            placeholderText: "Contraseña..."
            onAccepted: AuthService.authenticate(text)
            focus: true
        }
        Button {

        }
    }
}