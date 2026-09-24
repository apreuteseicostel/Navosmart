#pragma once
#include <QObject>
#include <QPointer>

class Vehicle;

// Exposes the real MissionManager ACK (including failures) to the QML uploader.
class NavoMissionBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(QObject* vehicle READ vehicle WRITE setVehicle NOTIFY vehicleChanged)
public:
    explicit NavoMissionBridge(QObject* parent = nullptr) : QObject(parent) {}
    QObject* vehicle() const;
    void setVehicle(QObject* object);
signals:
    void vehicleChanged();
    void uploadCompleted(bool success);
    void missionError(const QString& message);\n    void missionCompleted();
private:
    QPointer<Vehicle> _vehicle;
};
