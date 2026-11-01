import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property var controller: null
    implicitHeight: content.implicitHeight+20
    color: "#061827";border.color:controller && controller.active ? "#31d6a5" : "#19546b";radius:10
    ColumnLayout {
        id:content
        anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:10
        spacing:8
        Label { text:"STEALTH";font.pixelSize:16;font.bold:true;color:"#20d9ed" }
        RowLayout {
            Layout.fillWidth:true
            Label { Layout.fillWidth:true;text:"Viteză maximă m/s";color:"#c1d7e6";font.pixelSize:12 }
            SpinBox {
                objectName:"stealthSpeed";from:2;to:15;value:root.controller ? Math.round(root.controller.speedLimitMps*10) : 6
                textFromValue:function(v){return (v/10).toFixed(1)}
                valueFromText:function(t){return Math.round(Number(t.replace(",","."))*10)}
                onValueModified:if(root.controller)root.controller.setSpeedLimit(value)
            }
        }
        Label {
            Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#c1d7e6";font.pixelSize:11
            text:"Far oprit • poziții aprinse • sunete informative oprite. Alertele critice păstrează tonul; RGB și buzzerul H743 rămân neschimbate."
        }
        Button {
            objectName:"stealthToggle";Layout.fillWidth:true
            text:root.controller && root.controller.active ? "Dezactivează Stealth" : "Activează Stealth"
            enabled:!!root.controller && (root.controller.active || root.controller.canActivate)
            highlighted:!!root.controller && root.controller.active
            onClicked:if(root.controller){if(root.controller.active)root.controller.deactivate(true);else root.controller.activate()}
        }
        Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;font.pixelSize:11;color:"#31d6a5";text:root.controller ? root.controller.message : "Profil indisponibil" }
        Label { objectName:"stealthLightStatus";Layout.fillWidth:true;wrapMode:Text.WordWrap;font.pixelSize:11;color:"#ffd166"
            text:!root.controller || !root.controller.active ? "Lumini: control normal"
                : root.controller.lightState==="CONFIRMED" ? "Lumini: stare raportată H743 — far OFF / poziții ON"
                : root.controller.lightState==="UNAVAILABLE" ? "Stealth parțial: serviciul de lumini indisponibil"
                : root.controller.lightState==="PILOT" ? "Lumini: comandă manuală prioritară"
                : root.controller.lightState==="TIMEOUT" ? "Lumini: fără confirmare H743 în 5 s"
                : root.controller.lightState==="CHANGED" ? "Lumini: starea H743 s-a schimbat"
                : "Lumini: comandă solicitată, aștept telemetria H743"
        }
        Button { Layout.fillWidth:true;text:"Reaplică profilul de lumini";visible:!!root.controller && root.controller.active && ["UNAVAILABLE","PILOT","TIMEOUT","CHANGED"].indexOf(root.controller.lightState)>=0
            enabled:!!root.controller && root.controller.lightsReady;onClicked:root.controller.applyLights() }
        Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;font.pixelSize:11;color:"#c1d7e6";text:root.controller ? root.controller.speedState : "" }
        Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;font.pixelSize:10;color:"#9aaebd"
            text:"Viteza este solicitată doar în navigația NAVO AUTO/GUIDED; pilotajul manual și RTL nu sunt limitate. La dezactivare, farul anterior aprins este solicitat din nou; pozițiile rămân aprinse. Nu este confirmare mecanică sau măsurare a zgomotului." }
    }
}
