"""Load production safety/pre-launch objects and exercise Qt signal bindings."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
from pathlib import Path
from tempfile import TemporaryDirectory
from PySide6.QtCore import QUrl,QMetaObject,QObject,QSettings,Qt
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent,QQmlEngine
from PySide6.QtTest import QTest
app=QGuiApplication([]); engine=QQmlEngine(); errors=[]
engine.warnings.connect(lambda ws:errors.extend(str(w) for w in ws))
base=Path(__file__).resolve().parent.parent/'custom/qml'
c=QQmlComponent(engine,QUrl.fromLocalFile(str(base/'NavoSafetyManager.qml')))
s=c.create();assert s,c.errors()
s.setProperty('telemetryLive',True);s.setProperty('batteryTempC',60)
s.setProperty('waterSensorFault',True)
assert s.property('state')=='CRITICAL'
s.setProperty('batteryTempC',20);assert s.property('state')=='UNKNOWN'
s.setProperty('waterSensorFault',False);assert s.property('state')=='NORMAL'
s.setProperty('waterDetected',True);s.setProperty('waterValid',False)
assert not s.property('waterConfirmed') and s.property('state')=='UNKNOWN'
c2=QQmlComponent(engine,QUrl.fromLocalFile(str(base/'NavoPreLaunchCheck.qml')))
p=c2.create();assert p,c2.errors()
p.setProperty('sensorLabel','H743 / V3')
assert p.property('checks').toVariant()[4]['name']=='H743 / V3'
assert not errors,errors
print('PASS Qt safety bindings: independent hazards, invalid water, V3 pre-launch label')

with TemporaryDirectory() as config_dir:
    app.setOrganizationName("NavoTest")
    app.setApplicationName("HopperCalibration")
    QSettings.setDefaultFormat(QSettings.Format.IniFormat)
    QSettings.setPath(QSettings.Format.IniFormat, QSettings.Scope.UserScope, config_dir)
    hopper_test = QQmlComponent(engine)
    hopper_test.setData(b'''
import QtQuick
import QtQuick.Controls
import QtCore

ApplicationWindow {
    width: 260
    height: 340
    visible: true
    Settings {
        id: config
        objectName: "config"
        category: "NavoHopperCalibration"
        property bool confirmed: false
        property int leftOutput: 9
        property int rightOutput: 10
        property int leftClosed: 1500
        property int rightClosed: 1500
        property int leftOpen: 1900
        property int rightOpen: 1900
    }
    QtObject {
        id: sensors
        objectName: "sensors"
        property bool connected: false
        property bool waterValid: false
        property bool waterDetected: false
        property bool temperatureValid: false
        property real batteryTempC: 0
    }
    NavoHopperSettings {
        objectName: "form"
        anchors.fill: parent
        settings: config
        telemetry: sensors
    }
}
''', QUrl.fromLocalFile(str(base / 'HopperSettingsTest.qml')))
    window = hopper_test.create()
    assert window, hopper_test.errors()
    app.processEvents()

    def item(name):
        return window.findChild(QObject, name)

    config = item("config")
    form = item("form")
    left_output = item("hopperLeftOutput")
    right_output = item("hopperRightOutput")
    left_closed = item("hopperLeftClosed")
    save = item("saveHopperCalibration")
    dialog = item("confirmHopperCalibration")
    assert left_output.property("text") == "9"
    assert right_output.property("text") == "10"
    assert left_closed.property("text") == item("hopperRightClosed").property("text") == "1500"
    assert item("hopperLeftOpen").property("text") == item("hopperRightOpen").property("text") == "1900"

    left_output.setProperty("text", "10")
    assert not save.property("enabled")
    left_output.setProperty("text", "17")
    assert not save.property("enabled")
    left_output.setProperty("text", "")
    assert not save.property("enabled")
    left_output.setProperty("text", "9")
    assert save.property("enabled")

    left_closed.forceActiveFocus()
    QTest.keyClick(window, Qt.Key.Key_A, Qt.KeyboardModifier.ControlModifier)
    for key in (Qt.Key.Key_1, Qt.Key.Key_5, Qt.Key.Key_2, Qt.Key.Key_0):
        QTest.keyClick(window, key)
    assert left_closed.property("text") == "1520"
    assert config.property("leftClosed") == 1500
    assert QMetaObject.invokeMethod(save, "clicked")
    assert dialog.property("visible")
    assert QMetaObject.invokeMethod(dialog, "reject")
    assert config.property("leftClosed") == 1500 and not config.property("confirmed")
    assert QMetaObject.invokeMethod(save, "clicked")
    form.setProperty("busy", True)
    assert not save.property("enabled")
    assert QMetaObject.invokeMethod(dialog, "accept")
    assert config.property("leftClosed") == 1500 and not config.property("confirmed")
    form.setProperty("busy", False)
    assert QMetaObject.invokeMethod(save, "clicked")
    assert QMetaObject.invokeMethod(dialog, "accept")
    assert config.property("leftClosed") == 1520 and config.property("confirmed")
    assert not save.property("enabled")

    restarted_window = hopper_test.create()
    assert restarted_window, hopper_test.errors()
    assert restarted_window.findChild(QObject, "hopperLeftClosed").property("text") == "1520"
    assert restarted_window.findChild(QObject, "config").property("confirmed")
    restarted_window.close()

    mavlink = item("hopperMavlinkStatus")
    service = item("hopperV3Status")
    water = item("hopperWaterStatus")
    sensors = item("sensors")
    assert "fără legătură" in mavlink.property("text") and water.property("text").endswith("—")
    form.setProperty("linkAlive", True)
    assert "MAVLink conectat" in mavlink.property("text") and "fără date" in service.property("text")
    sensors.setProperty("connected", True)
    assert "serviciu activ" in service.property("text") and water.property("text").endswith("—")
    sensors.setProperty("waterValid", True)
    assert water.property("text").endswith("OK")
    form.setProperty("linkAlive", False)
    assert water.property("text").endswith("—")
    window.close()
    assert not errors, errors

print('PASS hopper numeric entry, validation, confirmed persistence and split telemetry status')
