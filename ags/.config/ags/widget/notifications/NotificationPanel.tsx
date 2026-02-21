import { Astal, Gdk, Gtk } from "ags/gtk4";
import { store, NotificacionIdividual } from "./Notification";
import AstalNotifd from "gi://AstalNotifd?version=0.1";
import app from "ags/gtk4/app";
import { createBinding, For } from "gnim";
import { exec, execAsync } from "ags/process";

export function NotificationPanel() {
    const notifid = AstalNotifd.get_default()
    const historico = createBinding(store,"lista")
    const isDND = createBinding(notifid, "dontDisturb");
    return <box cssClasses={["notifications-container"]} orientation={Gtk.Orientation.VERTICAL}>
            <box css={"margin: 5px;"} orientation={Gtk.Orientation.HORIZONTAL}>
                <label label={"Modo no molestar"}></label>
                <switch hexpand onNotifyActive={(self) => {
                    if (notifid.dontDisturb !== self.active) {
                        notifid.dontDisturb = self.active;
                    }
                }} active={isDND} valign={Gtk.Align.CENTER} halign={Gtk.Align.END}/>
            </box>
            <button onClicked={() => { store.lista.forEach(n => n.dismiss())
            store.lista = [];}}> <label label={"Limpiar todas.."}></label></button>
            <scrolledwindow vexpand maxContentHeight={500} css="min-height: 400px;" hexpand propagateNaturalWidth={false} hscrollbarPolicy={Gtk.PolicyType.NEVER} vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC} maxContentWidth={Gtk.ScrollStep.HORIZONTAL_ENDS}>
            <box orientation={Gtk.Orientation.VERTICAL} css={"padding: 5px;"}>
            <For each={historico}>
                {(val) => 
                    
                        <NotificacionIdividual notification={val} closeClicked={() => {
                        if (val.get_expire_timeout()!=val.time) {
                            val.dismiss()
                        }
                        store.lista = store.lista.filter(m => m.id != val.id)
                    }}/>
                    
                }
            </For>
            </box>
            </scrolledwindow>
    </box>
}
export function NotificacionVentana(gdkmonitor: Gdk.Monitor) {
    return <window
        gdkmonitor={gdkmonitor}
        namespace={"notification-panel"}
        class={"notification-panel"}
        exclusivity={Astal.Exclusivity.EXCLUSIVE}
        application={app}
        layer={Astal.Layer.TOP}
        keymode={Astal.Keymode.ON_DEMAND}
        name={"notifyPanel"} defaultHeight={600} width_request={400} heightRequest={600} widthRequest={400}>
            <NotificationPanel/>
    </window>
}
