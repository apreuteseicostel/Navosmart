import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id:root
    property var source:null
    property real viewWidth:320
    property real viewHeight:600
    property var captured:null
    property string editingId:""
    property bool resumeAfter:false
    property string status:""
    onSourceChanged:{resumeAfter=false;editor.close();catalog.close();deleteConfirm.close()}
    function locationText(note) {
        if(!note)return ""
        var t=typeof note.milliseconds==="number" && note.milliseconds>=0 ? (note.milliseconds/1000).toFixed(1)+" s" : "Timp indisponibil în KLF"
        return t+" • cadru "+note.frame+(typeof note.columnSequence==="number" ? " • coloană "+note.columnSequence : "")
    }
    function begin(column) {
        if(!source || !source.replayMode || !column || !column.replay || !column.replayAnchor || !column.replayAnchor.frame)return false
        var anchor=source.replayAnnotationAnchor
        if(!anchor || anchor.source!==column.replayAnchor.source)return false
        captured={anchor:Object.assign({},column.replayAnchor),depth:column.bottom,temp:column.temp}
        editingId="";status="";noteText.text=""
        resumeAfter=source.replayActive && !source.replayPaused
        if(resumeAfter)source.pauseReplay(true)
        editor.open();return true
    }
    function showNotes(){if(source && source.replayMode)catalog.open()}
    function edit(note) {
        if(!source || !source.replayMode)return
        captured={anchor:note,depth:note.depth,temp:note.temperature};editingId=note.id;status="";noteText.text=note.text
        resumeAfter=source.replayActive && !source.replayPaused
        if(resumeAfter)source.pauseReplay(true)
        editor.open()
    }
    function save() {
        if(!source || !captured || !source.replayMode)return false
        var ok=editingId.length ? source.editReplayAnnotation(editingId,noteText.text) : source.saveReplayAnnotation(captured.anchor,noteText.text,typeof captured.depth==="number" ? captured.depth : NaN,typeof captured.temp==="number" ? captured.temp : NaN)
        if(ok)editor.close()
        else status=source.replayAnnotationError || "Nota nu a fost salvată. Verifică sesiunea și textul (maximum 1.000 de caractere / 500 de note)."
        return ok
    }
    Connections {
        target:root.source || null;ignoreUnknownSignals:true
        function onReplayModeChanged(){if(!root.source || !root.source.replayMode){root.resumeAfter=false;editor.close();catalog.close();deleteConfirm.close()}}
        function onReplayAnnotationAnchorChanged(){
            if(editor.visible && root.captured && (!root.source.replayAnnotationAnchor || root.source.replayAnnotationAnchor.source!==root.captured.anchor.source)){
                root.resumeAfter=false;editor.close()
            }
        }
    }
    Dialog {
        id:editor;objectName:"replayNoteEditor";parent:Overlay.overlay;modal:false;dim:false
        title:root.editingId.length ? "Editează nota" : "Adnotare replay"
        width:Math.min(360,root.viewWidth-16);height:Math.min(300,root.viewHeight-16);anchors.centerIn:parent
        onClosed:{
            if(root.resumeAfter && root.source && root.source.replayMode && root.source.replayActive && root.captured && root.source.replayAnnotationAnchor && root.source.replayAnnotationAnchor.source===root.captured.anchor.source)root.source.pauseReplay(false)
            root.resumeAfter=false
        }
        contentItem:ScrollView {
            clip:true;contentWidth:availableWidth
            ColumnLayout {
                width:editor.availableWidth;spacing:6
                Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:root.captured ? root.locationText(root.captured.anchor) : ""}
                Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:"Observație pe coloana selectată. Poziție din înregistrare.";font.pixelSize:11;color:"#91a3b5"}
                TextArea {id:noteText;objectName:"replayNoteText";Layout.fillWidth:true;Layout.preferredHeight:100;placeholderText:"Ex: prag observat, ecou de verificat…";wrapMode:TextEdit.Wrap}
                Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;visible:root.status.length>0;text:root.status;color:"#ffbd69"}
            }
        }
        footer:DialogButtonBox {
            Button {objectName:"replayNoteSave";text:"Salvează";enabled:noteText.text.trim().length>0 && noteText.text.length<=1000;onClicked:root.save()}
            Button {text:"Renunță";onClicked:editor.close()}
        }
    }
    Dialog {
        id:catalog;objectName:"replayNotesCatalog";parent:Overlay.overlay;modal:false;dim:false
        title:"Note replay";width:Math.min(380,root.viewWidth-16);height:Math.min(340,root.viewHeight-16);anchors.centerIn:parent
        footer:DialogButtonBox {Button{text:"Închide";onClicked:catalog.close()}}
        contentItem:ColumnLayout {
            Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:root.source && root.source.replayAnnotationError ? root.source.replayAnnotationError : "Note salvate pentru această înregistrare.";font.pixelSize:11}
            Label {visible:!notesList.count;text:"Nu ai adnotări pentru acest replay."}
            ListView {
                id:notesList;objectName:"replayNotesList";Layout.fillWidth:true;Layout.fillHeight:true;clip:true;spacing:6
                model:root.source && root.source.replayAnnotations ? root.source.replayAnnotations : []
                delegate:ColumnLayout {
                    required property var modelData
                    width:notesList.width;spacing:4
                    Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:root.locationText(modelData);color:"#67dfdc";font.pixelSize:11}
                    Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:modelData.text}
                    Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;font.pixelSize:11;text:(typeof modelData.depth==="number" ? "Fund: "+modelData.depth.toFixed(2)+" m" : "Fund: --")+" • "+(typeof modelData.temperature==="number" ? modelData.temperature.toFixed(1)+" °C" : "Apă --")+" • "+(typeof modelData.latitude==="number" && typeof modelData.longitude==="number" ? modelData.latitude.toFixed(6)+", "+modelData.longitude.toFixed(6) : "GPS înregistrat indisponibil")}
                    RowLayout {
                        Button {text:"Editează";onClicked:root.edit(modelData)}
                        Button {text:"Șterge";onClicked:{deleteConfirm.noteId=modelData.id;deleteConfirm.open()}}
                    }
                }
                ScrollBar.vertical:ScrollBar {}
            }
        }
    }
    Dialog {
        id:deleteConfirm;objectName:"replayNoteDeleteConfirm";parent:Overlay.overlay;modal:true;title:"Ștergi nota?";property string noteId:""
        width:Math.min(300,root.viewWidth-16);anchors.centerIn:parent
        standardButtons:Dialog.Yes | Dialog.No
        onAccepted:if(root.source && root.source.replayMode)root.source.removeReplayAnnotation(noteId)
    }
}
