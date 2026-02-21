import { Astal, Gtk } from "ags/gtk4";
import { createPoll } from "ags/time";
import AstalNotifd from "gi://AstalNotifd?version=0.1";
import { createBinding, For, With } from "gnim";
import { Historico } from "../utils/HistorialNotificaciones";
import Pango from "gi://Pango?version=1.0";
export const store = new Historico()
export function NotificacionIdividual({notification, closeClicked}: {notification: AstalNotifd.Notification, closeClicked: (() => void)}) {
    const apps_famosas = {"firefox": "firefox"}
    const revision = () => notification.appIcon ? {iconName: notification.appIcon} : {file: notification.image}
    return <box heightRequest={40} widthRequest={60} cssClasses={["notification-box"]} orientation={Gtk.Orientation.VERTICAL}>
                    <box orientation={Gtk.Orientation.HORIZONTAL} spacing={10}>
                        <image {...revision()} visible={notification.appIcon || notification.image ? true : false} pixelSize={20}/>
                        <box orientation={Gtk.Orientation.VERTICAL}>
                            <label label={notification.appName} xalign={0}/>
                            <label label={notification.summary} widthRequest={700} hexpand xalign={0}/>
                            <label label={notification.body} wrapMode={Pango.WrapMode.WORD_CHAR} xalign={0} wrap/>
                            {notification.actions.length > 0 && (
                                <box orientation={Gtk.Orientation.HORIZONTAL} spacing={5} css={"margin-top: 10px;"}>
                                    {notification.actions.map(action => (
                                        <button hexpand cssClasses={["notification-action-button"]} onClicked={() => {
                                            action.invoke()
                                        }}>
                                            <label label={action.label}/>
                                        </button>
                                    ))}
                                </box>
                            )}
                        </box>
                        <button onClicked={closeClicked} valign={Gtk.Align.START} halign={Gtk.Align.END}>
                            <image iconName={"window-close-symbolic"}/>
                        </button>
                    </box>
                    
                </box>
}

export default function ListaNotificaciones() {
    const { TOP, RIGHT } = Astal.WindowAnchor;
    const notifid = AstalNotifd.get_default();
    notifid.set_default_timeout(5000)
    console.log(notifid.get_default_timeout())
    const notificaciones = createBinding(notifid,"notifications").as(notif => notif.sort(((a, b) => b.id - a.id)))
    notifid.connect("notified",(self,id) => {
                const n = self.get_notification(id);
                if (n && !store.lista.find(item => item.id == n.id)) {
                    // Reasignamos la lista para disparar la reactividad de gnim
                    store.lista = [n, ...store.lista];
                }
            })
    return <window class={"notification-popups"} namespace={"notification-popups"} name={"notifications-popups"} css={"background: transparent;"} defaultHeight={100} defaultWidth={200} anchor={RIGHT | TOP} visible={notificaciones.as(n => n.length > 0)}>
        <box cssClasses={["notification-popoup-container"]} orientation={Gtk.Orientation.VERTICAL} css={"padding: 10px;background: transparent;"}>
        <For each={notificaciones}>
        {(notificacion) => {
            notificacion.suppressSound = notifid.dontDisturb
            if (notifid.dontDisturb) {
                return <box visible={false}></box>
            }
            return <NotificacionIdividual notification={notificacion} closeClicked={() => {
                notificacion.dismiss()
                if (store.lista.find(l => l.id == notificacion.id)) {
                    store.lista = store.lista.filter(l => l.id != notificacion.id)
                }
            }}/>
        }}
        </For>
        </box>
    </window>
}