import QtQuick
import QtMultimedia

Item {
    id: root

    property string streamUrl: ""
    property string protocol: "auto" // auto, rtsp, mjpeg
    readonly property bool playing: player.playbackState === MediaPlayer.PlayingState
    readonly property string status: retryTimer.running
        ? "RECONNECT"
        : (player.error === MediaPlayer.NoError
            ? (playing ? "LIVE" : (streamUrl.length ? "READY" : "NO URL"))
            : player.errorString)
    property bool autoReconnect: true
    property bool desiredPlaying: false
    property int reconnectMs: 3000

    signal videoError(string message)

    function normalizedUrl() {
        var u = streamUrl.trim()
        if (!u.length)
            return ""
        if (protocol === "rtsp" && u.indexOf("://") < 0)
            return "rtsp://" + u
        return u
    }

    function start() {
        desiredPlaying = true
        var u = normalizedUrl()
        if (!u.length)
            return
        player.source = u
        player.play()
    }

    function stop() {
        desiredPlaying = false
        retryTimer.stop()
        player.stop()
    }

    function scheduleReconnect() {
        if (desiredPlaying && autoReconnect && streamUrl.length && !retryTimer.running)
            retryTimer.start()
    }

    Timer {
        id: retryTimer
        interval: root.reconnectMs
        repeat: false
        onTriggered: root.start()
    }

    AudioOutput {
        id: mutedAudio
        muted: true
    }

    MediaPlayer {
        id: player
        videoOutput: video
        audioOutput: mutedAudio

        onErrorOccurred: function(error, errorString) {
            root.videoError(errorString)
            root.scheduleReconnect()
        }

        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.StoppedState && root.desiredPlaying && root.streamUrl.length)
                root.scheduleReconnect()
        }
    }

    VideoOutput {
        id: video
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }
}
