import QtQuick
QtObject {
    id: root
    property real reservePercent: 25
    property real consumptionPercentPerKm: 12
    property bool calibrated: false
    function requiredPercent(distanceM){ return (Math.max(0,distanceM)/1000)*consumptionPercentPerKm + reservePercent }
    function canStart(distanceM,batteryPercent){ return !isNaN(batteryPercent) && (!calibrated || batteryPercent >= requiredPercent(distanceM)) }
    function message(distanceM,batteryPercent){ var r=requiredPercent(distanceM); if(!calibrated)return "Estimare energie ~"+r.toFixed(0)+"% • necalibrată"; return canStart(distanceM,batteryPercent) ? "Energie OK • necesar ~"+r.toFixed(0)+"%" : "Energie insuficientă • necesar ~"+r.toFixed(0)+"%" }
}