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
        // QGC 5.0.7 has no MissionManager::missionComplete signal. Use the
        // autopilot's reached-item message, not a locally inferred mode change.
        connect(next, &Vehicle::mavlinkMessageReceived, this,
                [this](const mavlink_message_t& message) {
            if (!_vehicle || message.sysid != _vehicle->id() ||
                message.compid != MAV_COMP_ID_AUTOPILOT1 ||
                message.msgid != MAVLINK_MSG_ID_MISSION_ITEM_REACHED) return;
            mavlink_mission_item_reached_t reached{};
            mavlink_msg_mission_item_reached_decode(&message, &reached);
            emit missionItemReached(reached.seq);
        });
        connect(next, &QObject::destroyed, this, [this]() {
            _vehicle = nullptr;
            emit vehicleChanged();
        });
    }
    emit vehicleChanged();
}
