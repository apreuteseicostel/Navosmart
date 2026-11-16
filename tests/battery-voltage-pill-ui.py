"""Render the production NAVO battery status pill and verify measured 4S voltage replaces SOC %."""
import os
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")
from pathlib import Path
import tempfile
import subprocess

import PySide6
from PySide6.QtCore import QResource, QUrl, QObject, Qt, QPoint
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtTest import QTest

repo = Path(__file__).resolve().parent.parent
source = (repo / "custom/qml/NavoDashboard.qml").read_text()
voltage_props_start = source.index("    readonly property real batteryVoltage:")
voltage_props_end = source.index("    property var waypointNames:", voltage_props_start)
voltage_props = source[voltage_props_start:voltage_props_end]
card = next(line for line in source.splitlines()
            if "StatusPill {" in line and 'title: "BATERIE"' in line)
assert "battery.percentRemaining" not in card
assert 'root.batteryVoltage.toFixed(2) + " V"' in card
assert 'dashboardDetails.showSection("battery")' in card
card = card.replace("StatusPill {",
                    'StatusPill { id: batteryCard; objectName: "batteryCard"; anchors.centerIn: parent; width: 86; height: 42;',
                    1)
component_start = source.index("    component StatusPill:")
component_end = source.index("    component NavButton:", component_start)
component = source[component_start:component_end]

qml = """import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ApplicationWindow {
  id: root
  visible: true
  width: 500
  height: 250
  color: "#071926"
  property bool linkAlive: true
  property bool compactUi: true
  property color ok: "#31d67b"
  property color text: "#edf8ff"
  property color line: "#174c68"
  property int detailOpens: 0
  QtObject { id: header; property real telemetryScale: 1 }
  QtObject { id: volts; objectName: "volts"; property real rawValue: 16.80 }
  QtObject { id: percent; objectName: "percent"; property real rawValue: 99 }
  QtObject { id: pack; property var voltage: volts; property var percentRemaining: percent }
  property var battery: pack
  QtObject {
    id: dashboardDetails
    function showSection(which) { if (which === "battery") root.detailOpens++ }
  }
""" + voltage_props + "\n" + card + "\n" + component + "\n}"

app = QGuiApplication([])
engine = QQmlApplicationEngine()
errors = []
engine.warnings.connect(lambda ws: errors.extend(str(w) for w in ws))

with tempfile.TemporaryDirectory() as directory:
    tmp = Path(directory)
    qrc, rcc = tmp / "icons.qrc", tmp / "icons.rcc"
    qrc.write_text('<RCC><qresource prefix="/qml/NavoSmart/icons">' +
                   ''.join(f'<file alias="{p.name}">{p}</file>'
                           for p in (repo / "custom/icons").glob("*.svg")) +
                   '</qresource></RCC>')
    subprocess.run([str(Path(PySide6.__file__).parent / "Qt/libexec/rcc"),
                    "--binary", str(qrc), "-o", str(rcc)], check=True)
    assert QResource.registerResource(str(rcc))
    file = tmp / "BatteryPill.qml"
    file.write_text(qml)
    engine.load(QUrl.fromLocalFile(str(file)))
    assert engine.rootObjects(), errors
    window = engine.rootObjects()[0]
    card_obj = window.findChild(QObject, "batteryCard")
    volts = window.findChild(QObject, "volts")
    percent = window.findChild(QObject, "percent")
    assert card_obj and volts and percent, errors
    QTest.qWait(70)

    def check(expected, good):
        QTest.qWait(30)
        got = card_obj.property("value")
        assert got == expected, (expected, got)
        assert bool(card_obj.property("good")) == good, (good, card_obj.property("good"))

    check("16.80 V", True)
    # Percentage must not influence the primary readout.
    percent.setProperty("rawValue", 1)
    check("16.80 V", True)
    volts.setProperty("rawValue", 15.64)
    check("15.64 V", True)
    volts.setProperty("rawValue", 0)
    check("--", False)
    volts.setProperty("rawValue", -1)
    check("--", False)
    volts.setProperty("rawValue", 65535)
    check("--", False)
    volts.setProperty("rawValue", 12.31)
    check("12.31 V", True)
    window.setProperty("linkAlive", False)
    check("--", False)
    window.setProperty("linkAlive", True)
    check("12.31 V", True)
    QTest.mouseClick(window, Qt.LeftButton, Qt.NoModifier,
                     QPoint(window.width() // 2, window.height() // 2))
    QTest.qWait(30)
    assert window.property("detailOpens") == 1, window.property("detailOpens")
    assert not errors, errors
    print("PASS real 4S BATERIE status: measured volts, no SOC %, missing/invalid/connection checks, battery popup remains clickable")
