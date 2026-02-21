import { Gtk } from "ags/gtk4";
import Pango from "gi://Pango";
import AstalMpris from "gi://AstalMpris?version=0.1";
import { createBinding, With } from "gnim";
import { createPoll } from "ags/time";

const player = AstalMpris.Mpris.get_default()
const players = createBinding(player, "players")
const activePlayer = players(ps => {
        const filtered = ps.filter(p => !p.busName.includes("playerctld"))
        return filtered.find(p => p.playbackStatus === AstalMpris.PlaybackStatus.PLAYING) || filtered[0]
    })

function formatTime(seconds: number) {
    const min = Math.floor(seconds / 60)
    const sec = Math.floor(seconds % 60)
    return `${min}:${sec < 10 ? "0" + sec : sec}`
}

function MediaDashboard() {
    //
    return <With value={activePlayer}>
            {(playe) => {
                if (!playe) return <box/>
                const title = createBinding(playe, "title")
                const artist = createBinding(playe, "artist")
                const artUrl = createBinding(playe, "artUrl")
                const status = createBinding(playe, "playbackStatus")
                const length = createBinding(playe, "length")
                const position = createBinding(playe,"position")
                const adj = length.as(l => new Gtk.Adjustment({upper: l > 0 ? l : 1, step_increment: 1, lower: 0, ...position.as(p => {value: p})}))
                
                // Poll for position as it's not always signaled

                return <box orientation={Gtk.Orientation.VERTICAL} cssClasses={["media-dashboard"]} spacing={12}>
                            <box cssClasses={["media-art"]} css={artUrl.as(url => `background-image: url('${url}');
                                min-width: 320px;
                                min-height: 220px;
                                background-size: cover;
                                background-position: center;
                                border-radius: 12px;
                                border: 1px solid rgba(255,255,255,0.15);`)}>
                            </box>
                            <box orientation={Gtk.Orientation.VERTICAL} cssClasses={["media-info"]} halign={Gtk.Align.CENTER} spacing={8}>
                                <label wrap maxWidthChars={28} label={title.as(t => t || "Desconocido")} css="font-size: 1.2em; font-weight: 800;"/>
                                <label justify={Gtk.Justification.CENTER} wrap maxWidthChars={28} label={artist.as(a => a || "Artista Desconocido")} css="font-size: 0.9em; opacity: 0.8; margin-top: 4px;"/>
                            
                            </box>
                            <box orientation={Gtk.Orientation.HORIZONTAL}>
                                <label xalign={0} label={position.as(p => formatTime(p))}/>
                                <slider adjustment={adj} hexpand onChangeValue={({value}) => playe.set_position(value)}></slider>
                                <label xalign={1} label={length.as(l => formatTime(l > 0 ? l : 1))}/>
                            </box>
                            <box orientation={Gtk.Orientation.HORIZONTAL} halign={Gtk.Align.CENTER} spacing={16} cssClasses={["media-controls"]}>
                                <button onClicked={() => playe.previous()} cssClasses={["media-control-btn"]}>
                                    <label label={"󰒮"}/>
                                </button>
                                <button onClicked={() => playe.play_pause()} cssClasses={["media-control-btn", "play-pause-btn"]}>
                                    <label label={status.as(s => s === AstalMpris.PlaybackStatus.PLAYING ? "" : "")}></label>
                                </button>
                                <button onClicked={() => playe.next()} cssClasses={["media-control-btn"]}>
                                    <label label={"󰒭"}></label>
                                </button>
                            </box>
                            
            </box>}}
        </With>
}

export default function Reproductor() {
    return (
        <box spacing={2}>
            <With value={activePlayer}>
                {(val) => (
                    <box cssClasses={["media-box-1"]}>
                        <button
                            cssClasses={["media-button"]}
                            onClicked={() => val?.previous()}
                            sensitive={!!val}
                        >
                            <label label={"󰒮"} />
                        </button>
                        <button
                            cssClasses={["media-button"]}
                            onClicked={() => val?.play_pause()}
                            sensitive={!!val}>
                            <label label={val ? createBinding(val, "playbackStatus").as(s => s === AstalMpris.PlaybackStatus.PLAYING ? "" : ""): ""}/>
                        </button>
                        <button
                            cssClasses={["media-button"]}
                            onClicked={() => val?.next()}
                            sensitive={!!val}
                        >
                            <label label={"󰒭"} />
                        </button>
                        {val ? (
                            <menubutton cssClasses={["media-title"]}>
                                <label
                                    ellipsize={Pango.EllipsizeMode.END}
                                    maxWidthChars={15}
                                    label={createBinding(val, "title").as(t => t || "Desconocido")}
                                />
                                <popover>
                                    <MediaDashboard />
                                </popover>
                            </menubutton>
                        ) : (
                            <label
                                cssClasses={["media-title"]}
                                css="padding: 0 12px;"
                                ellipsize={Pango.EllipsizeMode.END}
                                maxWidthChars={15}
                                label="Sin medios"
                            />
                        )}
                    </box>
                )}
            </With>
        </box>
    )
}
