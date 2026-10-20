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
                (message.msgid != MAVLINK_MSG_ID_MISSION_ITEM_REACHED &&
                 message.msgid != MAVLINK_MSG_ID_RC_CHANNELS)) return;
            if (message.msgid == MAVLINK_MSG_ID_RC_CHANNELS) {
                mavlink_rc_channels_t rc{};
                mavlink_msg_rc_channels_decode(&message, &rc);
                const uint16_t raw[] = {rc.chan1_raw, rc.chan2_raw, rc.chan3_raw, rc.chan4_raw,
                    rc.chan5_raw, rc.chan6_raw, rc.chan7_raw, rc.chan8_raw, rc.chan9_raw,
                    rc.chan10_raw, rc.chan11_raw, rc.chan12_raw, rc.chan13_raw, rc.chan14_raw,
                    rc.chan15_raw, rc.chan16_raw};
                QVariantList channels;
                for (int i=0; i<16; ++i)
                    channels.append(i < rc.chancount && raw[i] >= 900 && raw[i] <= 2100 ? int(raw[i]) : 0);
                emit rcChannelsReceived(channels);
                return;
            }
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
