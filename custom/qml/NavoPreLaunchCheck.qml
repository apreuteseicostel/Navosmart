import QtQuick

QtObject {
    id: root
    property bool vehicleConnected: false
    property bool gpsReady: false
    property bool homeReady: false
    property bool batteryReady: false
    property bool nanoReady: false
    property bool sonarReady: false
    property bool cameraReady: false
    property bool hoppersReady: false

    readonly property bool navigationReady: vehicleConnected && gpsReady && homeReady && batteryReady
    readonly property int warningCount: (nanoReady?0:1)+(sonarReady?0:1)+(cameraReady?0:1)+(hoppersReady?0:1)
    readonly property string state: navigationReady ? (warningCount ? "WARNING" : "READY") : "BLOCKED"
    readonly property string blockingMessage: !vehicleConnected ? "PRE-LAUNCH blocat: H743/MAVLink deconectat"
                                            : !gpsReady ? "PRE-LAUNCH blocat: GPS fără fix valid"
                                            : !homeReady ? "PRE-LAUNCH blocat: HOME nu este valid"
                                            : !batteryReady ? "PRE-LAUNCH blocat: bateria este indisponibilă sau sub pragul de siguranță"
                                            : ""
    readonly property var checks: [
        {name:"H743 / MAVLink", ok:vehicleConnected, critical:true},
        {name:"UM982 / GPS", ok:gpsReady, critical:true},
        {name:"HOME", ok:homeReady, critical:true},
        {name:"Baterie", ok:batteryReady, critical:true},
        {name:"Nano", ok:nanoReady, critical:false},
        {name:"Kogger", ok:sonarReady, critical:false},
        {name:"Camera", ok:cameraReady, critical:false},
        {name:"Cuve", ok:hoppersReady, critical:false}
    ]
}
