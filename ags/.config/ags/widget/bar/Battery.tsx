import { execAsync } from "ags/process"
import AstalBattery from "gi://AstalBattery?version=0.1"
import { createBinding } from "gnim"

export default function BatteryPercentage() {
  const percentaje = createBinding(AstalBattery.get_default(),"percentage")
  const estiloBateria = percentaje.as((p) => {
    const lista = []
    if (p < 0.2) {
      lista.push("battery-critical")
    } else if (p < 0.3) {
      lista.push("battery-warning")
    }
    return lista
  })
  const icono = createBinding(AstalBattery.get_default(),"iconName")
  return (<box cssClasses={estiloBateria}>
          <image iconName={icono(icono => icono)}/>
          <label label={percentaje(p => `${Math.round(p * 100)}%`)}></label>
        </box>
      )
}