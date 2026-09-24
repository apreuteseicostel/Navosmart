#include "NavoMissionBridge.h"
#include "Vehicle.h"
#include "MissionManager.h"

QObject* NavoMissionBridge::vehicle() const { return _vehicle.data(); }

void NavoMissionBridge::setVehicle(QObject* object) {
    auto* next = qobject_cast<Vehicle*>(object);
    if (next == _vehicle) return;
    if (_vehicle) {
        disconnect(_vehicle, nullptr, this, nullptr);
        if (_vehicle->missionManager())
            disconnect(_vehicle->missionManager(), nullptr, this, nullptr);
    }
    _vehicle = next;
    if (next) {
        if (auto* manager = next->missionManager()) {
            connect(manager, &MissionManager::sendComplete, this,
                    [this](bool error) { emit uploadCompleted(!error); });
            connect(manager, &MissionManager::error, this,
                    [this](int, const QString& message) { emit missionError(message); });
        }
        connect(next, &QObject::destroyed, this, [this]() {
            _vehicle = nullptr;
            emit vehicleChanged();
        });
    }
    emit vehicleChanged();
}
