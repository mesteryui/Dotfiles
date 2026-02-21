import { Astal, Gtk, Gdk } from "ags/gtk4"
import app from "ags/gtk4/app"
import { exec } from "ags/process"


export default function PowerMenu(gdkmonitor: Gdk.Monitor) {
    const { TOP, LEFT, RIGHT } = Astal.WindowAnchor
    return (<window name={"power"}
        gdkmonitor={gdkmonitor}
        namespace={"power-menu"}
        exclusivity={Astal.Exclusivity.EXCLUSIVE}
        application={app}
        keymode={Astal.Keymode.ON_DEMAND}
        >
        <box spacing={10}>
            <button onClicked={() => exec("hyprlock;ags toggle power")}>
                <label label={"\nBloquear"}/>
            </button>
            <button onClicked={() => exec("systemctl suspend")}>
                <label label={"\nSuspender"}></label>
            </button>
            <button onClicked={() => exec("systemctl poweroff")}>
                <label label={"\nApagar"}></label>
            </button>
        </box>
    </window>)
}