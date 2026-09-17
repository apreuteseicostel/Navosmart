import QtQuick
QtObject {
    id: root
    property real reservePercent: 25
    property real consumptionPercentPerKm: 12
    function requiredPercent(distanceM){ return (Math.max(0,distanceM)/1000)*consumptionPercentPerKm + reservePercent }
    function canStart(distanceM,batteryPercent){ return !isNaN(batteryPercent) && batteryPercent >= requiredPercent(distanceM) }
    function message(distanceM,batteryPercent){ var r=requiredPercent(distanceM); return canStart(distanceM,batteryPercent) ? "Energie OK • necesar ~"+r.toFixed(0)+"%" : "Misiune blocată • necesar ~"+r.toFixed(0)+"%" }
}