import QtQuick
QtObject {
    id: root
    property real reservePercent: 25
    property real consumptionPercentPerKm: 12
    property bool calibrated: false
    function requiredPercent(distanceM){
        if(!isFinite(distanceM)||distanceM<0||!isFinite(consumptionPercentPerKm)||consumptionPercentPerKm<=0||!isFinite(reservePercent)||reservePercent<0||reservePercent>100)return NaN
        return (distanceM/1000)*consumptionPercentPerKm + reservePercent
    }
    function canStart(distanceM,batteryPercent){
        if(!calibrated)return true
        var required=requiredPercent(distanceM)
        return isFinite(required)&&isFinite(batteryPercent)&&batteryPercent>=0&&batteryPercent<=100&&batteryPercent>=required
    }
    function message(distanceM,batteryPercent){
        var r=requiredPercent(distanceM)
        if(!calibrated)return "Verificare energie dezactivată • calibrează consumul"
        if(!isFinite(r)||!isFinite(batteryPercent)||batteryPercent<0||batteryPercent>100)return "Energie: traseu, HOME sau baterie indisponibile"
        return canStart(distanceM,batteryPercent) ? "Energie OK • necesar ~"+r.toFixed(0)+"%" : "Energie insuficientă • necesar ~"+r.toFixed(0)+"%"
    }
}
