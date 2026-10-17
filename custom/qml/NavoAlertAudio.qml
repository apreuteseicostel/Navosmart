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
    property string soundError:""
    property string lastPlaybackStatus:""
    function play(sound,voice,text,critical) {
        if(sound) {
            if(soundAvailable) {
                tone.stop()
                tone.play()
                lastPlaybackStatus="Sunet: comandă de redare trimisă"
            } else {
                lastPlaybackStatus="Sunet indisponibil (status "+tone.status+"): verifică resursa audio și ieșirea Android"
            }
        }
        // A critical alert may interrupt a previous NAVO phrase; ordinary events
        // do not build a queue of stale warnings after a telemetry burst.
        if(voice && voiceAvailable && (critical || speech.state===TextToSpeech.Ready))speech.say(text)
        else if(voice && !voiceAvailable)lastPlaybackStatus += " • Voce indisponibilă"
    }
    function stop() { tone.stop();speech.stop() }
    SoundEffect { id:tone;source:"qrc:/qml/NavoSmart/audio/alert.wav";volume:root.volume;onStatusChanged:if(status===SoundEffect.Error)root.soundError="Eroare la încărcarea fișierului audio NAVO" }
    TextToSpeech {
        id:speech;volume:root.volume
        locale:Qt.locale("ro_RO")
        onErrorOccurred:function(error,errorString){root.voiceError=errorString}
    }
}
