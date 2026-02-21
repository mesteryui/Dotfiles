import AstalHyprland from "gi://AstalHyprland?version=0.1"
import { createBinding, For } from "gnim"

export default function Workspaces() { 
  const hyprland = AstalHyprland.get_default() 
  const binded = createBinding(hyprland, "workspaces").as(ws => ws.filter((ws) => ws.id > 0).sort((a, b) => a.id - b.id))
  const focused = createBinding(hyprland,"focusedWorkspace")
  return ( // Ese <For each={valor}></For> es un bucle pero se usa para las binding permite recorrer de forma más eficiente colecciones cambiantes
      <box spacing={3} cssClasses={["workspaces"]}>
      <For each={binded}>
        {(each) => 
          <button cssClasses={focused.as((fw) => {
            const classes = ["workspace"]
            if (fw?.id == each.id) classes.push("active");
            else if (each.clients.length > 0) classes.push("ocupado");
            return classes
          })} onClicked={() => hyprland.dispatch("workspace",`${each.id}`)}>

          <label label={`${each.id}`}></label>
        </button>
        }
      </For>
      </box>
  ) 
}
