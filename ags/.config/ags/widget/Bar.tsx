import app from "ags/gtk4/app"
import { Astal, Gtk, Gdk } from "ags/gtk4"
import { execAsync } from "ags/process"
import { createBinding, With } from "gnim"
import AstalWp from "gi://AstalWp?version=0.1"
import Workspaces from "./bar/Workspaces"
import BatteryPercentage  from "./bar/Battery"
import Reloj from "./bar/Reloj"
import Reproductor from "./bar/Media"
import Tray from "./bar/TrayIcons"
import NetworkShow from "./bar/Network" 
import BluetoothConnected from "./bar/Bluetooth"
import { NotificationPanel } from "./notifications/NotificationPanel"
import AstalNotifd from "gi://AstalNotifd?version=0.1"
import HyprlandSubmaps from "./bar/HyprlandSubmaps"
import Dashboard from "./bar/Dashboard"
function GetVolumen() {
  const altavoz = AstalWp.Wp.get_default()
  if (!altavoz) return <box/>
  const speaker = createBinding(altavoz.audio, "default_speaker")
  
  return <With value={speaker}>
    {(s) => {
      if (!s) return <box/>
      const vol = createBinding(s, "volume")
      const icon = createBinding(s, "volume_icon")
      return (
        <button
          onClicked={() => execAsync("xdg-terminal-exec --app-id=local.floating -e wiremix")}
          cssClasses={["volume-widget"] } 
        >
          <box cssClasses={["volume-box"]} spacing={5}>
            <image iconName={icon}/>
            <label label={vol.as(v => `${Math.round(v * 100)}%`)}/>
          </box>
        </button>
      )
    }}
  </With>
}

export default function Bar(gdkmonitor: Gdk.Monitor) {
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor

  return (
    <window
      visible
      name={`bar-${gdkmonitor.get_model() || "default"}`}
      class="Bar"
      layer={Astal.Layer.BOTTOM}
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={TOP | LEFT | RIGHT}
      application={app}
    >
      <centerbox cssName="centerbox">
        <box $type="start" halign={Gtk.Align.START} spacing={8}>
          <button 
            cssClasses={["launcher"]}
            onClicked={() => execAsync("walker -s hyprsphere")}
          >
            <image file={`./assets/menu.png`} pixelSize={24}/>
          </button>
          <Workspaces/>
          <HyprlandSubmaps/>
        </box>
        <box $type="center" halign={Gtk.Align.CENTER} spacing={8}>
          <Reproductor/>
          <Reloj format="%A %H:%M"/>
        </box>
        <box $type="end" halign={Gtk.Align.END} spacing={8}>
          <Tray/>
          <NetworkShow/>
          <menubutton cssClasses={["notification-button"]}>
            <label label={createBinding(AstalNotifd.get_default(),"dontDisturb").as(v => v ? "󰪑" : "")}/>
            <popover>
              <NotificationPanel/>
            </popover>
          </menubutton>
          <BatteryPercentage/>
          <GetVolumen/>
        </box>
      </centerbox>
    </window>
  )
}
