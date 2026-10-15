import QtQuick
import QtMultimedia
import QtTextToSpeech

Item {
    id:root
    property real volume:0.7
    readonly property bool busy:speech.state===TextToSpeech.Speaking
    readonly property bool voiceAvailable: speech.engine.length>0 && speech.state!==TextToSpeech.Error
    readonly property bool soundAvailable: tone.status===SoundEffect.Ready
    property string voiceError:""
    function play(sound,voice,text,critical) {
        if(sound && soundAvailable){tone.stop();tone.play()}
        // A critical alert may interrupt a previous NAVO phrase; ordinary events
        // do not build a queue of stale warnings after a telemetry burst.
        if(voice && voiceAvailable && (critical || speech.state===TextToSpeech.Ready))speech.say(text)
    }
    function stop() { tone.stop();speech.stop() }
    SoundEffect { id:tone;source:"qrc:/qml/NavoSmart/audio/alert.wav";volume:root.volume }
    TextToSpeech {
        id:speech;volume:root.volume
        locale:Qt.locale("ro_RO")
        onErrorOccurred:function(error,errorString){root.voiceError=errorString}
    }
}
