import { Astal, Gtk } from "ags/gtk4"
import AstalBluetooth from "gi://AstalBluetooth?version=0.1"
import AstalNetwork from "gi://AstalNetwork?version=0.1"
import GLib from "gi://GLib?version=2.0"
import { createBinding } from "gnim"

export default function Dashboard() {
    const home = GLib.getenv("HOME")
    const user = GLib.get_real_name()
    const network = AstalNetwork.get_default()
    return <box cssClasses={["user-dashboard"]} orientation={Gtk.Orientation.VERTICAL}>
        <box cssClasses={["user-box"]} orientation={Gtk.Orientation.HORIZONTAL} spacing={10}>
            <image cssClasses={["user-image"]} pixelSize={60} file={home+"/.face"}></image>
            <label label={user}></label>
        </box>
    </box>
}