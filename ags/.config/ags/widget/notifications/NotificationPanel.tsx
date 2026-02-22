import { Astal, Gdk, Gtk } from "ags/gtk4";
import { store, NotificacionIndividual } from "./Notification";
import AstalNotifd from "gi://AstalNotifd?version=0.1";
import app from "ags/gtk4/app";
import { createBinding, For } from "gnim";
import { exec, execAsync } from "ags/process";

export function NotificationPanel() {
    const notifid = AstalNotifd.get_default()
    const historico = createBinding(store,"lista")
    const isDND = createBinding(notifid, "dontDisturb");
    
    return <box cssClasses={["notifications-container"]} orientation={Gtk.Orientation.VERTICAL} spacing={10}>
            <box orientation={Gtk.Orientation.HORIZONTAL} cssClasses={["notifications-header"]}>
                <label 
                    css={"font-size: 1.4rem; font-weight: 800; margin-left: 8px;"} 
                    halign={Gtk.Align.START} 
                    label={"Notificaciones"} 
                    hexpand
                />
                <button 
                    cssClasses={["clear-all-button"]}
                    visible={historico.as(l => l.length > 0)} 
                    onClicked={() => { 
                        store.lista.forEach(n => n.dismiss())
                        store.lista = [];
                    }}
                > 
                    <label label={"Limpiar todas"}/>
                </button>
            </box>

            <box cssClasses={["dnd-container"]} orientation={Gtk.Orientation.HORIZONTAL} spacing={10}>
                <label label={"Modo no molestar"} hexpand halign={Gtk.Align.START}/>
                <switch 
                    onNotifyActive={(self) => {
                        if (notifid.dontDisturb !== self.active) {
                            notifid.dontDisturb = self.active;
                        }
                    }} 
                    active={isDND} 
                    valign={Gtk.Align.CENTER} 
                    halign={Gtk.Align.END}
                />
            </box>
            
            <scrolledwindow 
                vexpand 
                css="min-height: 450px;" 
                hexpand 
                propagateNaturalWidth={false} 
                hscrollbarPolicy={Gtk.PolicyType.NEVER} 
                vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
            >
                <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
                    <For each={historico}>
                        {(val) => 
                            <NotificacionIndividual notification={val} closeClicked={() => {
                                if (val.get_expire_timeout() != val.time) {
                                    val.dismiss()
                                }
                                store.lista = store.lista.filter(m => m.id != val.id)
                            }}/>
                        }
                    </For>
                    <box 
                        visible={historico.as(l => l.length === 0)} 
                        orientation={Gtk.Orientation.VERTICAL} 
                        valign={Gtk.Align.CENTER} 
                        halign={Gtk.Align.CENTER} 
                        vexpand
                        hexpand
                        spacing={10}
                        css={"opacity: 0.5;"}
                    >
                        <image iconName={"notification-disabled-symbolic"} pixelSize={64}/>
                        <label label={"Sin notificaciones"}/>
                    </box>
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
        name={"notifyPanel"} heightRequest={600} widthRequest={460}>
            <NotificationPanel/>
    </window>
}
