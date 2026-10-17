import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

GroupBox {
    id:root
    title:"Alerte sonore și vocale"
    property var controller:null
    property var audio:null
    function apply() { if(controller)controller.configure(sound.checked,voice.checked,volume.value) }
    ColumnLayout {
        anchors.fill:parent
        CheckBox { id:sound;objectName:"alertsSound";text:"Sunet";checked:root.controller ? root.controller.soundEnabled : false;onToggled:root.apply() }
        CheckBox { id:voice;objectName:"alertsVoice";text:"Voce";checked:root.controller ? root.controller.voiceEnabled : false;onToggled:root.apply() }
        Slider { id:volume;Layout.fillWidth:true;from:0;to:1;value:root.controller ? root.controller.volume : 0.7;onMoved:root.apply() }
        Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#bbcbd9";text:"Voce: "+(root.audio && root.audio.voiceAvailable ? "disponibilă" : "indisponibilă pe acest dispozitiv")+" • Sunet: "+(root.audio && root.audio.soundAvailable ? "pregătit" : "indisponibil")+" • Volum: "+Math.round(volume.value*100)+"%" }
        Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#ffb56b";visible:!!root.audio && root.audio.voiceError.length>0;text:root.audio ? root.audio.voiceError : "" }
        Button { text:"Testează";enabled:!!root.controller && (sound.checked || voice.checked);onClicked: { root.apply(); root.controller.test() } }
        Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#bbcbd9";text:"Baterie ≤20%, pierdere legătură/GPS, apă confirmată, temperatură ≥55°C și sfârșit ciclu de nădire. Alertele automate sunt oprite în replay." }
        Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#21b7ff";text:root.controller ? root.controller.latest : "" }
    }
}
