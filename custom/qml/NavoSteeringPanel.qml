import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Rectangle {
    id:root
    property var controller
    signal enableRequested()
    color:"#102536";radius:8;implicitHeight:body.implicitHeight+16
    ColumnLayout {
        id:body;anchors.fill:parent;anchors.margins:8;spacing:6
        Label {text:"ASISTENȚĂ CÂRMĂ • H743";color:"white";font.bold:true}
        Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#d7e3ee";text:"STEERING: H743 menține direcția când manșa de direcție este neutră. Viteza rămâne comandată din G20. Necesită motor + cârmă configurate și calibrate."}
        Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#ffc857";text:root.controller ? root.controller.message : "H743 indisponibil"}
        Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#d7e3ee";visible:!!root.controller && !root.controller.busy;text:root.controller ? root.controller.availabilityMessage : ""}
        Flow {Layout.fillWidth:true;spacing:6
            Button {objectName:"steeringEnable";text:"ACTIVEAZĂ";enabled:!!root.controller && root.controller.canEnable;onClicked:confirmation.open()}
            Button {objectName:"steeringStop";text:"OPREȘTE • HOLD";enabled:!!root.controller && root.controller.busy && !root.controller.readOnly;onClicked:root.controller.stop()}
        }
    }
    Dialog {
        id:confirmation;objectName:"steeringConfirmation";parent:Overlay.overlay;anchors.centerIn:parent
        width:Math.min(400,parent ? parent.width-24 : 400);height:Math.min(280,parent ? parent.height-24 : 280);modal:true;title:"Activează STEERING?";standardButtons:Dialog.Ok|Dialog.Cancel
        contentItem:ScrollView {clip:true;contentWidth:availableWidth;Label {width:parent.width;wrapMode:Text.WordWrap;text:"Pune manșele la neutru înainte de schimbarea modului. H743 va controla cârma și propulsia conform configurării sale; apoi viteza se comandă din G20. Verifică zona liberă."}}
        onAccepted:root.enableRequested()
    }
}
