import AstalTray from "gi://AstalTray?version=0.1";
import { createBinding, For } from "gnim";

export default function Tray() {
    const tray = AstalTray.Tray.get_default()
    const items = createBinding(tray, "items")

    return <box cssClasses={["tray-box"]} spacing={0} visible={items(items => items.length >= 1)}>
        <For each={items}>
            {(item) => (
                <menubutton cssClasses={["tray-item"]}
                    tooltipMarkup={createBinding(item, "tooltipMarkup")}
                    menuModel={createBinding(item, "menuModel")}
                    alwaysShowArrow={false}
                    $={(self) => {
                        const sync = () => {
                            if (item.actionGroup) {
                                self.insert_action_group("dbusmenu", item.actionGroup)
                            }
                        }
                        item.connect("notify::action-group", sync)
                        sync()
                    }}>
                    <image gicon={createBinding(item, "gicon")} />
                </menubutton>
            )}
        </For>
    </box>
}
