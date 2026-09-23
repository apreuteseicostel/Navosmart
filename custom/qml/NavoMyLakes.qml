import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
 id:root
 property var persistence
 property var scanCoordinator
 property string selectedLakeId:""
 property var selectedLake:null
 modal:true;focus:true;width:Math.min(560,parent?parent.width-24:560);height:Math.min(620,parent?parent.height-24:620);anchors.centerIn:parent
 background:Rectangle{color:"#081522";border.color:"#1c4262";radius:12}
 function sessionsForLake(id){var out=[];if(!persistence)return out;for(var i=0;i<persistence.bathymetrySessions.length;i++){var s=persistence.bathymetrySessions[i];if(s.lakeId===id)out.push(s)}return out}
 function selectLake(lake){selectedLake=lake;selectedLakeId=lake?lake.id:"";if(scanCoordinator&&lake){scanCoordinator.lakeId=lake.id;scanCoordinator.lakeName=lake.name||"Baltă"}}
 signal openSession(var session)
 signal lakeRestored(string lakeId)
 ColumnLayout {
  anchors.fill:parent;anchors.margins:14;spacing:10
  RowLayout{Layout.fillWidth:true;Label{text:"BĂLȚILE MELE";color:"#21b7ff";font.bold:true;font.pixelSize:20}Item{Layout.fillWidth:true}Button{text:"ÎNCHIDE";onClicked:root.close()}}
  RowLayout{Layout.fillWidth:true;TextField{id:newLakeName;Layout.fillWidth:true;placeholderText:"Nume baltă / lac"}Button{text:"+ ADAUGĂ";enabled:newLakeName.text.trim().length>0;onClicked:{var id=root.persistence.saveLake({name:newLakeName.text.trim()});newLakeName.clear();for(var i=0;i<root.persistence.lakes.length;i++)if(root.persistence.lakes[i].id===id){root.selectLake(root.persistence.lakes[i]);root.scanCoordinator.checkpoint("lake-created");break}}}}
  SplitView{Layout.fillWidth:true;Layout.fillHeight:true;orientation:root.width<500?Qt.Vertical:Qt.Horizontal
   handle:Rectangle{implicitWidth:4;implicitHeight:4;color:"#1c4262"}
   ListView{SplitView.preferredWidth:Math.min(190,root.width*.36);SplitView.preferredHeight:root.width<500?130:root.height-130;clip:true;model:root.persistence?root.persistence.lakes:[];delegate:Button{required property var modelData;width:ListView.view.width;text:modelData.name||"Baltă";checkable:true;checked:root.selectedLakeId===modelData.id;onClicked:root.selectLake(modelData)}}
   ColumnLayout{SplitView.fillWidth:true
    Label{text:root.selectedLake?(root.selectedLake.name||"Baltă"):"Selectează o baltă";color:"#f2f7fb";font.bold:true;font.pixelSize:18}
    Label{visible:!!root.selectedLake;text:root.selectedLake?root.sessionsForLake(root.selectedLakeId).length+" scanări batimetrice salvate":"";color:"#9db2c5"}
    ListView{Layout.fillWidth:true;Layout.fillHeight:true;clip:true;model:root.selectedLake?root.sessionsForLake(root.selectedLakeId):[];delegate:Rectangle{required property var modelData;width:ListView.view.width;height:82;radius:8;color:"#0d2235";border.color:"#1c4262";Column{anchors.left:parent.left;anchors.leftMargin:10;anchors.verticalCenter:parent.verticalCenter;Label{text:modelData.name||"Scanare";color:"#f2f7fb";font.bold:true}Label{text:(modelData.sampleCount||0)+" puncte • "+Number(modelData.minDepthM||0).toFixed(1)+"–"+Number(modelData.maxDepthM||0).toFixed(1)+" m";color:"#9db2c5"}}Button{anchors.right:parent.right;anchors.rightMargin:8;anchors.verticalCenter:parent.verticalCenter;text:"HARTĂ";onClicked:root.openSession(modelData)}}}
    RowLayout{Layout.fillWidth:true;visible:!!root.selectedLake
     Button{text:"ÎNCARCĂ / RESUME";onClicked:{if(root.scanCoordinator&&root.scanCoordinator.restoreLake(root.selectedLakeId)){root.lakeRestored(root.selectedLakeId);root.close()}}}
     Item{Layout.fillWidth:true}
     Label{text:"Sonar • puncte • Area Scan";color:"#31d67b"}
    }
   }
  }
 }
}
