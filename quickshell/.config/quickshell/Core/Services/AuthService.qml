pragma Singleton
import Quickshell
import Quickshell.Services.Pam

Singleton {
    id: root
    signal successUnlocking()
    signal failedUnlocking()

    PamContext {
        id: pam
        onCompleted: result => {
            if (result == PamResult.Success) {
                root.successUnlocking()
            } else {
                root.failedUnlocking()
            }
        }
    }
}