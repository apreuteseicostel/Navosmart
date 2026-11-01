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
    function validConfiguration() {
        return !backend || (address.text.trim().length>0 && webPort.acceptableInput && webPort.text.length>0 && uartPort.acceptableInput && uartPort.text.length>0 && Number(webPort.text)!==Number(uartPort.text))
    }
    function saveConfiguration() {
        if(!backend)return true
        return apply(true) && backend.saveConfiguration()
    }
    function apply(requireUart) {
        if(!backend || !validConfiguration())return false
        backend.host=address.text.trim();backend.monitorPort=Number(webPort.text);backend.uartPort=uartPort.text.length ? Number(uartPort.text) : 0
        return true
    }
    component Info: Label { Layout.fillWidth:true;wrapMode:Text.WrapAnywhere;color:"#bfd6e5";font.pixelSize:11 }
    component Action: Button {
        id:action
        Layout.fillWidth:true;Layout.minimumWidth:0;implicitHeight:38;padding:7;font.pixelSize:12
        background:Rectangle {radius:9;color:action.down ? "#174c60" : action.hovered ? "#103d50" : "#08273a";border.color:action.enabled ? "#20d9ed" : "#537b91";border.width:1.3}
        contentItem:Label {text:action.text;color:action.enabled ? "#eff9ff" : "#9aaebd";font.pixelSize:action.font.pixelSize;font.bold:true;wrapMode:Text.WordWrap;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}
    }
    component Field: TextField {
        id:field
        Layout.fillWidth:true;Layout.minimumWidth:0;implicitHeight:36;padding:8;font.pixelSize:12
        color:"#eff9ff";placeholderTextColor:"#9ebacf";selectionColor:"#167998";selectedTextColor:"#ffffff";selectByMouse:true
        background:Rectangle {radius:7;color:"#092439";border.width:field.activeFocus ? 2 : 1;border.color:field.activeFocus ? "#20d9ed" : "#537b91"}
    }
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
        Info { text:"Adresă IP convertor ED2" }
        Field { id:address;objectName:"lanTargetHost";placeholderText:"192.168.144.7" }
        Info { text:"Port web / Port TCP UART" }
        RowLayout {
            Layout.fillWidth:true
            Field { id:webPort;objectName:"lanWebPort";Layout.fillWidth:true;Layout.minimumWidth:0;placeholderText:"Port web (de obicei 80)";validator:IntValidator { bottom:1;top:65535 }
                inputMethodHints:Qt.ImhDigitsOnly }
            Field { id:uartPort;objectName:"lanUartPort";Layout.fillWidth:true;Layout.minimumWidth:0;placeholderText:"Port TCP UART";validator:IntValidator { bottom:1;top:65535 }
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
