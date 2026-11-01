import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property var backend: null
    property bool expanded: false
    implicitHeight: body.implicitHeight+20
    color:"#061827";radius:8;border.color:"#31506a"
    onVisibleChanged: if(!visible && backend)backend.stopUart()
    onExpandedChanged: if(!expanded && backend)backend.stopUart()
    Component.onDestruction: if(backend)backend.stopUart()
    function load() {
        if(!backend)return
        address.text=backend.host
        webPort.text=String(backend.monitorPort)
        uartPort.text=backend.uartPort>0 ? String(backend.uartPort) : ""
    }
    Component.onCompleted: load()
    onBackendChanged: Qt.callLater(load)
    function apply(requireUart) {
        if(!backend || !address.text.trim().length || !webPort.acceptableInput || !webPort.text.length || (requireUart && (!uartPort.acceptableInput || !uartPort.text.length)))return false
        backend.host=address.text.trim();backend.monitorPort=Number(webPort.text);backend.uartPort=uartPort.text.length ? Number(uartPort.text) : 0
        return true
    }
    component Info: Label { Layout.fillWidth:true;wrapMode:Text.WrapAnywhere;color:"#bfd6e5";font.pixelSize:11 }
    component Action: Button { Layout.fillWidth:true;implicitHeight:36;font.pixelSize:11 }
    ColumnLayout {
        id:body;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:10;spacing:6
        Info { text:"LAN / TEST CONVERTOR UART";font.bold:true;color:"#eff9ff";font.pixelSize:12 }
        Info { objectName:"lanDiagnosticStatus";text:root.backend ? root.backend.status : "Diagnoză LAN indisponibilă";color:root.backend && root.backend.online ? "#31d67b" : "#ffd166" }
        Action { objectName:"lanExpand";text:root.expanded ? "Ascunde diagnoza UART" : "Configurează LAN / testează UART";onClicked:root.expanded=!root.expanded }
        ColumnLayout {
            Layout.fillWidth:true;visible:root.expanded;spacing:6
        Info { text:"LED-ul LINK al switch-ului confirmă legătura fizică. Din G20 verificăm un dispozitiv accesibil prin rețea; alimentarea switch-ului nu este măsurată direct." }
        Repeater {
            model:root.backend ? root.backend.interfaces : []
            delegate:Info {
                required property var modelData
                text:(modelData.ethernet ? "Ethernet local" : "Wi-Fi local")+": "+modelData.name+" • "+modelData.ip+" / "+modelData.mask+" • link "+(modelData.link ? "ON" : "neconfirmat")
            }
        }
        TextField { id:address;objectName:"lanTargetHost";Layout.fillWidth:true;placeholderText:"IP LAN al convertorului ED2";selectByMouse:true }
        RowLayout {
            Layout.fillWidth:true
            TextField { id:webPort;objectName:"lanWebPort";Layout.fillWidth:true;Layout.minimumWidth:0;placeholderText:"Port web (de obicei 80)";validator:IntValidator { bottom:1;top:65535 }
                inputMethodHints:Qt.ImhDigitsOnly }
            TextField { id:uartPort;objectName:"lanUartPort";Layout.fillWidth:true;Layout.minimumWidth:0;placeholderText:"Port TCP UART";validator:IntValidator { bottom:1;top:65535 }
                inputMethodHints:Qt.ImhDigitsOnly }
        }
        Info { text:"ED2 trebuie configurat TCP Server. Portul web și portul UART sunt diferite. Oprește alte aplicații/conexiuni la UART înainte de test; unele convertoare acceptă un singur client." }
        RowLayout {
            Layout.fillWidth:true
            Action { objectName:"lanVerify";text:"Verifică LAN";enabled:!!root.backend && !root.backend.suspended;onClicked:if(root.apply(false)){root.backend.monitoring=true;root.backend.verify()} }
            Action { objectName:"lanMonitorStop";text:"Oprește verificarea";enabled:!!root.backend;onClicked:root.backend.monitoring=false }
        }
        RowLayout {
            Layout.fillWidth:true
            Action { objectName:"lanUartConnect";text:"Ascultă UART";enabled:!!root.backend && !root.backend.suspended && !root.backend.uartConnected;onClicked:if(root.apply(true))root.backend.connectUart() }
            Action { objectName:"lanUartStop";text:"Închide UART";enabled:!!root.backend;onClicked:root.backend.stopUart() }
        }
        Info { objectName:"lanUartStatus";text:root.backend ? root.backend.uartStatus : "" }
        Info { objectName:"lanRxCount";text:"RX: "+(root.backend ? String(root.backend.received) : "0")+" octeți • fără transmisie UART" }
        ScrollView {
            Layout.fillWidth:true;Layout.preferredHeight:100;clip:true
            TextArea { objectName:"lanUartPreview";readOnly:true;selectByMouse:true;text:root.backend ? root.backend.preview : "";wrapMode:TextEdit.WrapAnywhere;font.family:"monospace";font.pixelSize:10;color:"#eff9ff";background:Rectangle { color:"#092a3c" } }
        }
        Action { text:"Șterge previzualizarea";enabled:!!root.backend;onClicked:root.backend.clearPreview() }
        }
    }
}
