import { Astal } from "ags/gtk4";
import AstalNotifd from "gi://AstalNotifd?version=0.1";
import GObject from "gnim/gobject";

export class Historico extends GObject.Object {
    lista: Array<AstalNotifd.Notification>
    static {
        GObject.registerClass({
            Properties: {
                "lista": GObject.ParamSpec.jsobject("lista","","", GObject.ParamFlags.READWRITE)
            },
        }, this);
    }
    constructor() {
        super()
        this.lista = [];
    }
}