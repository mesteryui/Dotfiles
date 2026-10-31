import QtQuick
import QtMultimedia

// Reproductor de fondo animado: el ÚNICO fichero de la shell con
// `import QtMultimedia`. Se carga siempre vía Loader con URL (nunca con tipo
// estático) para que la ausencia del módulo falle solo en ese Loader —con
// fallback al frame estático— en vez de romper la shell entera.
Item {
    id: root

    property url videoSource
    property bool playing: true

    // El póster se extrae en el segundo 1 (extract-wallpaper-frame.sh):
    // arrancar ahí evita el salto póster(s1) -> vídeo(s0). Un solo intento
    // por fuente: si al cargar ya se pasó del s1 no se retrocede (sería un
    // salto visible), y las reanudaciones tras pausa siguen donde quedaron.
    property bool _seekDone: false

    onVideoSourceChanged: root._seekDone = false

    function maybeSeekToPoster() {
        if (root._seekDone)
            return;
        const loaded = player.mediaStatus === MediaPlayer.LoadedMedia || player.mediaStatus
              === MediaPlayer.BufferedMedia;
        if (!loaded || player.duration <= 1000)
            return;
        if (player.position >= 1000) {
            root._seekDone = true;
            return;
        }
        player.position = 1000;
        root._seekDone = true;
    }

    function startPlayback() {
        root.maybeSeekToPoster();
        player.play();
    }

    MediaPlayer {
        id: player

        source: root.videoSource
        videoOutput: video
        // Sin audioOutput a proposito: es un fondo (siempre mudo). Ni
        // siquiera se abre el dispositivo ni se decodifica la pista de
        // audio si el video trae una: menos RAM y menos hilos.
        autoPlay: root.playing
        loops: MediaPlayer.Infinite
        onErrorOccurred: (error, errorString) => {
            console.warn("[Wallpaper] error reproduciendo video (" + error + "): " + errorString);
        }
        // Carga lenta: el seek al s1 se intenta al completar la carga,
        // no solo al pulsar play (ver maybeSeekToPoster).
        onMediaStatusChanged: root.maybeSeekToPoster()
    }

    VideoOutput {
        id: video

        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }

    // Estado de reproducción hacia fuera (la capa de fondo lo usa para
    // fundir el vídeo solo cuando hay imagen real).
    readonly property int playbackState: player.playbackState

    readonly property bool isPlaying: player.playbackState === MediaPlayer.PlayingState
    // Hay frame visible (reproduciendo o en pausa): distingue "nunca
    // arrancado" (póster estático) de "pausado" (último frame congelado).

    readonly property bool hasVideo: player.playbackState !== MediaPlayer.StoppedState

    // Control imperativo (el vigilante de la capa lo usa para re-emitir
    // play si el backend se queda clavado; el binding playing cubre el
    // camino normal). Pasa por startPlayback para el seek al s1.
    function play() {
        root.startPlayback();
    }

    function pause() {
        player.pause();
    }

    // Parada ordenada del backend (suelta el decodificador; la pausa lo
    // retenía). La capa lo llama antes de descargar el Loader, y el
    // vigilante nunca lo usa para reanudar (eso es play()). OJO: no se
    // toca `player.source` aquí: es un binding a root.videoSource y
    // asignarlo a mano lo rompería para siempre en este item.
    function stop() {
        root._seekDone = false;
        player.stop();
    }

    onPlayingChanged: {
        if (root.playing)
            root.startPlayback();
        else
            player.pause();
    }
}
