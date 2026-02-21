import AstalHyprland from "gi://AstalHyprland?version=0.1";
import { createBinding, With } from "gnim";
import { Submapa } from "../utils/CurrentSubmap";

export default function HyprlandSubmaps() {
    const hyprland = AstalHyprland.get_default()
    const currentSubmap = new Submapa()
    hyprland.connect("submap", (_,name) => {
        currentSubmap.submapa = name === "default" ? "" : name
    })
    const actualidad = createBinding(currentSubmap,"submapa")
    return <With value={actualidad}> 
        {(mapa) => <box visible={mapa === "" ? false : true}>
            <label label={mapa}/>
        </box>}
    </With>
}