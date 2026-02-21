import { Gtk } from "ags/gtk4"
import { createPoll } from "ags/time"
import GLib from "gi://GLib?version=2.0"

export default function Reloj({format = "%H:%M"}) {
  const time = createPoll("", 1000, () => {
    return GLib.DateTime.new_now_local().format(format) ?? "Invalido"
  })
  return <menubutton cssClasses={["clock"]} $type="center" hexpand halign={Gtk.Align.CENTER}>
          <label label={time} />
          <popover>
            <Gtk.Calendar />
          </popover>
        </menubutton>
}