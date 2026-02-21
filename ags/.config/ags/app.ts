import app from "ags/gtk4/app"
import style from "./style.scss"
import Bar from "./widget/Bar"
import PowerMenu from "./widget/PowerMenu"
import Notificacion from "./widget/notifications/Notification"
import ListaNotificaciones from "./widget/notifications/Notification"
import { NotificacionVentana } from "./widget/notifications/NotificationPanel"
import { Astal } from "ags/gtk4"
import AstalNotifd from "gi://AstalNotifd?version=0.1"
import { exec, execAsync } from "ags/process"

app.start({
  css: style,
  main() {
    app.get_monitors().map(Bar)
    app.get_monitors().map(ListaNotificaciones)
    app.get_monitors().map(NotificacionVentana)
  },
  requestHandler(argv, res) {
    const command = argv[0]
    switch (command) {
      case "dontDisturbToggle":
        const notifid = AstalNotifd.get_default()
        notifid.dontDisturb = notifid.dontDisturb ? false : true
        res(`${notifid.dontDisturb ? "Activando" : "Desactivando"} modo no molestar`)
        break
      case "restart":
        execAsync("./reload.sh")
        break
      default:
        res("No existe el comando " + command)
    }
  },
})
