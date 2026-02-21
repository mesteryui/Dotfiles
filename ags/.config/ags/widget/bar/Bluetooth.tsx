import AstalBluetooth from "gi://AstalBluetooth?version=0.1";
import { createBinding, With } from "gnim";

export default function BluetoothConnected() {
    const bluetooth = AstalBluetooth.Bluetooth.get_default()
    const device = createBinding(bluetooth,"isConnected")
    return <With value={device}>
        {(val) => <box>
                <image iconName={val ? "bluetooth_connected" : "bluetooth_disconnected"}></image>
            </box>}
    </With>
}