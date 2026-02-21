import { execAsync } from "ags/process";
import AstalNetwork from "gi://AstalNetwork?version=0.1";
import { createBinding, With } from "gnim";

export default function NetworkShow() {
    const network = AstalNetwork.Network.get_default()
    const wifi = createBinding(network,"wifi")
    return <With value={wifi}>
            {(val) => <button tooltipText={`Red: ${val.ssid}`} cssClasses={["network-widget"]} onClicked={() => execAsync("xdg-terminal-exec --app-id=local.floating -e gazelle")}>
                    <box>
                        <image iconName={createBinding(val,"iconName").as(wifi => wifi || "󱘖")}></image>
                    </box>
                </button>}
        </With>
}