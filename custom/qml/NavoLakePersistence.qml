import QtQuick
import QtCore

QtObject {
    id: root
    property string lakeId: ""
    property string lakeName: ""
    property var scanState: ({})
    property var samples: []
    property var areaPoints: []
    property var fishingSpots: []\n    property var bathymetry3DCache: ({})
    property string lastError: ""
    readonly property url dataFolder: StandardPaths.writableLocation(StandardPaths.AppDataLocation) + "/navosmart"

    signal saved(string lakeId)
    signal loaded(string lakeId)
    signal failed(string message)

    function _safeId(value) {
        var s=(value||"lake").toString().toLowerCase().replace(/[^a-z0-9_-]/g,"_")
        return s.length?s:"lake"
    }
    function _fileUrl(id) { return dataFolder + "/" + _safeId(id) + ".json" }

    // Payload format is deliberately versioned so future releases can migrate
    // saved lakes without forcing a rescan.
    function buildPayload() {
        return {
            schemaVersion: 1,
            lakeId: _safeId(lakeId),
            lakeName: lakeName,
            savedAt: Date.now(),
            areaPoints: areaPoints,
            fishingSpots: fishingSpots,
            scanState: scanState,
            samples: samples
        }
    }

    // Persistence is exposed as serialized JSON. The host/backend writes this
    // atomically; keeping serialization here makes the saved format testable.
    function serialize() { return JSON.stringify(buildPayload()) }

    function restore(jsonText) {
        try {
            var p=JSON.parse(jsonText)
            if(!p || p.schemaVersion!==1) throw "Versiune fișier necunoscută"
            lakeId=p.lakeId||""
            lakeName=p.lakeName||""
            areaPoints=p.areaPoints||[]
            fishingSpots=p.fishingSpots||[]
            scanState=p.scanState||({})
            samples=p.samples||[]\n            bathymetry3DCache=p.bathymetry3DCache||({})
            lastError=""
            loaded(lakeId)
            return true
        } catch(e) {
            lastError=e.toString(); failed(lastError); return false
        }
    }

    function clearInMemory() {
        lakeId=""; lakeName=""; scanState=({}); samples=[]; areaPoints=[]; fishingSpots=[]; bathymetry3DCache=({}); lastError=""
    }
}
