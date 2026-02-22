import { Astal, Gtk } from "ags/gtk4";
import { createPoll } from "ags/time";
import AstalNotifd from "gi://AstalNotifd?version=0.1";
import { createBinding, For, With } from "gnim";
import { Historico } from "../utils/HistorialNotificaciones";
import Pango from "gi://Pango?version=1.0";
export const store = new Historico()
const notifid = AstalNotifd.get_default()
const notificaciones = createBinding(notifid,"notifications").as(notif => { 
    if (notifid.dontDisturb) return [];
    return notif.sort(((a, b) => b.id - a.id))})
notifid.connect("notified",(self,id) => {
                const n = self.get_notification(id);
                if (n && !store.lista.find(item => item.id == n.id)) {
                    // Reasignamos la lista para disparar la reactividad de gnim
                    store.lista = [n, ...store.lista.filter(i => i.id !== n.id)];
                }
                if (n) n.suppressSound = notifid.dontDisturb
            })
export function NotificacionIndividual({notification, closeClicked}: {notification: AstalNotifd.Notification, closeClicked: (() => void)}) {
    const revision = () => notification.appIcon ? {iconName: notification.appIcon} : {file: notification.image}
    return <box orientation={Gtk.Orientation.VERTICAL} cssClasses={["notification-box"]}>
                    <box orientation={Gtk.Orientation.HORIZONTAL} spacing={12}>
                        {(notification.appIcon || notification.image) && (
                            <box valign={Gtk.Align.START} cssClasses={["notification-icon-container"]}>
                                <image {...revision()} pixelSize={38}/>
                            </box>
                        )}
                        <box orientation={Gtk.Orientation.VERTICAL} hexpand spacing={2}>
                            <box orientation={Gtk.Orientation.HORIZONTAL}>
                                <label 
                                    label={notification.appName || "Notificación"} 
                                    xalign={0} 
                                    hexpand 
                                    cssClasses={["notification-app-name"]} 
                                    ellipsize={Pango.EllipsizeMode.END}
                                />
                                <button 
                                    onClicked={closeClicked} 
                                    valign={Gtk.Align.START} 
                                    halign={Gtk.Align.END} 
                                    cssClasses={["notification-close-button"]}
                                >
                                    <image iconName={"window-close-symbolic"} pixelSize={14}/>
                                </button>
                            </box>
                            <label 
                                label={notification.summary} 
                                useMarkup={true}
                                hexpand 
                                xalign={0} 
                                cssClasses={["notification-summary"]} 
                                wrap 
                                wrapMode={Pango.WrapMode.WORD_CHAR} 
                                ellipsize={Pango.EllipsizeMode.END}
                            />
                            {notification.body && (
                                <label 
                                    label={notification.body} 
                                    useMarkup={true}
                                    wrapMode={Pango.WrapMode.WORD_CHAR} 
                                    xalign={0} 
                                    wrap 
                                    cssClasses={["notification-body"]}
                                />
                            )}
                            {notification.actions.length > 0 && (
                                <box orientation={Gtk.Orientation.HORIZONTAL} spacing={6} css={"margin-top: 8px;"}>
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
                    </box>
                </box>
}

export default function ListaNotificaciones() {
    const { TOP, RIGHT } = Astal.WindowAnchor;
    notifid.set_default_timeout(5000)
    console.log(notifid.get_default_timeout())
    return <window class={"notification-popups"} namespace={"notification-popups"} name={"notifications-popups"} css={"background: transparent;"} defaultHeight={100} defaultWidth={460} widthRequest={460} anchor={RIGHT | TOP} visible={notificaciones.as(n => n.length > 0)}>
        <box cssClasses={["notification-popoup-container"]} orientation={Gtk.Orientation.VERTICAL} css={"padding: 10px;background: transparent;"}>
        <For each={notificaciones}>
        {(notificacion) => {
            return <NotificacionIndividual notification={notificacion} closeClicked={() => {
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