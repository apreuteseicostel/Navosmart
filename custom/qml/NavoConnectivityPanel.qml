import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    property var controller: null
    property var sonar: null
    property var camera: null
    property bool videoLive: false
    property string checkResult: ""
    signal backRequested()
    spacing:8
    function syncRows() {
        var rows=controller ? controller.connections : []
        for(var i=0;i<rows.length;i++) {
            if(i<links.count && links.get(i).key!==rows[i].key)links.remove(i,links.count-i)
            var row={key:String(rows[i].key),name:String(rows[i].name),endpoint:String(rows[i].endpoint),stateText:String(rows[i].state),detail:String(rows[i].detail||""),live:!!rows[i].live,canConnect:!!rows[i].canConnect,received:String(rows[i].bytes||0)}
            if(i<links.count)links.set(i,row);else links.append(row)
        }
        if(links.count>rows.length)links.remove(rows.length,links.count-rows.length)
    }
    onControllerChanged:syncRows()
    Component.onCompleted:syncRows()
    Connections { target:root.controller;function onConnectionsChanged(){root.syncRows()} }
    ListModel { id:links }
    component Command: Button {
        implicitHeight:34;padding:5
        contentItem:Label { text:parent.text;font.pixelSize:11;color:parent.enabled ? "#eff9ff" : "#80929e";horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;wrapMode:Text.WordWrap }
        background:Rectangle { radius:7;color:parent.down ? "#15516a" : "#092a3c";border.color:parent.enabled ? "#20d9ed" : "#405363" }
    }
    RowLayout {
        Layout.fillWidth:true
        Label { Layout.fillWidth:true;text:"CONECTIVITATE";color:"#eff9ff";font.bold:true;font.pixelSize:14 }
        Command { objectName:"connectivityBack";text:"Înapoi";onClicked:root.backRequested() }
    }
    CheckBox {
        objectName:"connectivityAuto"
        text:"Conectare automată NAVO la pornire"
        checked:!!root.controller && root.controller.autoConnect
        enabled:!!root.controller
        onClicked:root.controller.autoConnect=checked
        contentItem:Label { text:parent.text;color:"#eff9ff";font.pixelSize:12;leftPadding:parent.indicator.width+parent.spacing;wrapMode:Text.WordWrap }
        Layout.fillWidth:true
    }
    Label {
        Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#bfd6e5";font.pixelSize:11
        text:"Se verifică porturile MAVLink și adresele salvate. USB/TCP deschis nu înseamnă autopilot conectat: este necesar HEARTBEAT recent. Pe Android, QGC permite un singur USB serial simultan."
    }
    RowLayout {
        Layout.fillWidth:true
        Command { objectName:"connectivityAll";Layout.fillWidth:true;text:"Conectează toate";enabled:!!root.controller && !root.controller.busy;onClicked:root.controller.connectAll() }
        Command { objectName:"connectivityRefresh";Layout.fillWidth:true;text:"Verifică porturile";enabled:!!root.controller;onClicked:root.controller.refresh() }
    }
    Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;text:root.controller ? root.controller.status : "Serviciu de conectivitate indisponibil";color:"#9be9e2";font.pixelSize:11 }
    Repeater {
        model:links
        delegate:Rectangle {
            required property string key
            required property string name
            required property string endpoint
            required property string stateText
            required property string detail
            required property bool live
            required property bool canConnect
            required property string received
            Layout.fillWidth:true;implicitHeight:entry.implicitHeight+16
            color:"#061827";border.color:live ? "#31d67b" : "#31506a";radius:8
            ColumnLayout {
                id:entry;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:8;spacing:4
                Label { Layout.fillWidth:true;text:name;wrapMode:Text.WordWrap;color:"#eff9ff";font.bold:true;font.pixelSize:12 }
                Label { Layout.fillWidth:true;text:endpoint;wrapMode:Text.WrapAnywhere;color:"#bfd6e5";font.pixelSize:11 }
                Label { Layout.fillWidth:true;text:stateText;wrapMode:Text.WordWrap;color:live ? "#31d67b" : "#ffd166";font.pixelSize:11 }
                Label { Layout.fillWidth:true;text:detail;visible:text.length>0;wrapMode:Text.WordWrap;color:"#bfd6e5";font.pixelSize:11 }
                Label { text:"RX: "+received+" octeți";color:"#bfd6e5";font.pixelSize:10 }
                RowLayout {
                    Layout.fillWidth:true
                    Command { objectName:"connectivityConnect";text:"Conectează";Layout.fillWidth:true;enabled:canConnect && !!root.controller;onClicked:root.controller.connectOne(key) }
                    Command { objectName:"connectivityVerify";text:"Verifică";Layout.fillWidth:true;enabled:!!root.controller;onClicked:root.controller.verifyOne(key) }
                }
            }
        }
    }
    Label { visible:links.count===0;Layout.fillWidth:true;wrapMode:Text.WordWrap;text:"Niciun port MAVLink detectat încă. Verifică alimentarea H743 și permisiunea USB; pentru GR01 verifică și conexiunea de date oferită de G20.";color:"#bfd6e5";font.pixelSize:11 }
    Rectangle {
        Layout.fillWidth:true;implicitHeight:tcpForm.implicitHeight+16;color:"#061827";border.color:"#31506a";radius:8
        ColumnLayout {
            id:tcpForm;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:8;spacing:6
            Label { Layout.fillWidth:true;text:"TELEMETRIE TCP • G20 / GR01";color:"#eff9ff";font.bold:true;font.pixelSize:12;wrapMode:Text.WordWrap }
            Label { Layout.fillWidth:true;text:"Dacă GR01 nu apare ca port serial, folosește adresa și portul de telemetrie furnizate de G20. Nu sunt adresa camerei sau a sonarului.";wrapMode:Text.WordWrap;color:"#bfd6e5";font.pixelSize:11 }
            TextField { id:tcpHost;objectName:"connectivityTcpHost";Layout.fillWidth:true;placeholderText:"Adresă IP telemetrie";selectByMouse:true }
            TextField { id:tcpPort;objectName:"connectivityTcpPort";Layout.fillWidth:true;placeholderText:"Port TCP";inputMethodHints:Qt.ImhDigitsOnly;validator:IntValidator { bottom:1;top:65535 } }
            Command { objectName:"connectivityAddTcp";Layout.fillWidth:true;text:"Salvează și conectează TCP";enabled:!!root.controller && tcpHost.text.trim().length>0 && tcpPort.text.length>0 && tcpPort.acceptableInput;onClicked:root.controller.addTcp(tcpHost.text.trim(),Number(tcpPort.text)) }
            Label { Layout.fillWidth:true;text:"Viteză USB serial (pentru porturile NAVO încă neconectate)";wrapMode:Text.WordWrap;color:"#bfd6e5";font.pixelSize:11 }
            ComboBox { objectName:"connectivityBaud";Layout.fillWidth:true;model:[115200,57600,921600];currentIndex:root.controller ? Math.max(0,model.indexOf(root.controller.serialBaud)) : 0;onActivated:if(root.controller)root.controller.setSerialBaud(Number(currentText)) }
        }
    }
    Rectangle {
        Layout.fillWidth:true;implicitHeight:extras.implicitHeight+16;color:"#061827";border.color:"#31506a";radius:8
        ColumnLayout {
            id:extras;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:8;spacing:6
            Label { Layout.fillWidth:true;text:"SONAR • "+(!root.sonar ? "indisponibil" : root.sonar.replayMode ? "REDARE • nu este conexiune live" : root.sonar.dataAlive ? "ECOGRAMĂ LIVE" : root.sonar.connected ? "Transport deschis • fără ecogramă live" : "Deconectat");wrapMode:Text.WordWrap;color:root.sonar && root.sonar.dataAlive ? "#31d67b" : "#bfd6e5";font.pixelSize:12 }
            RowLayout {
                Layout.fillWidth:true
                Command { objectName:"connectivitySonarConnect";Layout.fillWidth:true;text:"Conectează sonar";enabled:!!root.sonar && !root.sonar.replayMode && !root.sonar.connected && root.sonar.port>0 && root.sonar.port<=65535 && (root.sonar.udp || String(root.sonar.host).length>0);onClicked:root.sonar.connectSonar() }
                Command { objectName:"connectivitySonarVerify";Layout.fillWidth:true;text:"Verifică";enabled:!!root.sonar;onClicked:root.checkResult=root.sonar.replayMode ? "Sonar: redare, fără date live" : "Sonar: "+root.sonar.status+(root.sonar.dataAlive ? " • ecogramă validă și recentă" : " • fără ecogramă live") }
            }
            Label { Layout.fillWidth:true;text:"CAMERĂ • "+(root.videoLive ? "VIDEO LIVE" : root.camera && root.camera.connected ? "Transport deschis • video neconfirmat" : "Deconectată / video neconfirmat");wrapMode:Text.WordWrap;color:root.videoLive ? "#31d67b" : "#bfd6e5";font.pixelSize:12 }
            RowLayout {
                Layout.fillWidth:true
                Command { objectName:"connectivityCameraConnect";Layout.fillWidth:true;text:"Conectează cameră";enabled:!!root.camera && !root.camera.connected && root.camera.port>0 && root.camera.port<=65535 && (root.camera.udp || String(root.camera.host).length>0);onClicked:root.camera.connectCamera() }
                Command { objectName:"connectivityCameraVerify";Layout.fillWidth:true;text:"Verifică";onClicked:root.checkResult=root.videoLive ? "Cameră: video decodat live" : "Cameră: video neconfirmat; verifică URL-ul în Integrare" }
            }
            Label { Layout.fillWidth:true;text:"Adresele sonarului și camerei se configurează în Integrare.";wrapMode:Text.WordWrap;color:"#bfd6e5";font.pixelSize:11 }
        }
    }
    Label { Layout.fillWidth:true;visible:root.checkResult.length>0;text:root.checkResult;wrapMode:Text.WordWrap;color:"#9be9e2";font.pixelSize:11 }
}
