import GObject from "gnim/gobject";

export class Submapa extends GObject.Object {
    submapa: string
    static {
        GObject.registerClass({
            Properties: {
                "submapa": GObject.ParamSpec.string("submapa","","",GObject.ParamFlags.READWRITE,"")
                
            },
        }, this);
    }
    constructor() {
        super()
        this.submapa = ""
    }
}