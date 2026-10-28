"""Exercise the production settings QML in Qt 6; mock network/video only."""
import os
import pathlib
import shutil
import tempfile

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")
from PySide6.QtCore import QPoint, QUrl, Qt
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickItem, QQuickWindow
from PySide6.QtTest import QTest

app = QGuiApplication([])
app.setOrganizationName("NavoSettingsTest")
app.setApplicationName("KoggerControls")
source = pathlib.Path(__file__).resolve().parents[1] / "custom/qml/NavoEthernetSettings.qml"

with tempfile.TemporaryDirectory() as folder:
    temp = pathlib.Path(folder)
    os.environ["XDG_CONFIG_HOME"] = str(temp / "config")
    shutil.copy(source, temp / source.name)
    backend = temp / "NavoSmart/Backend"
    backend.mkdir(parents=True)
    (backend / "qmldir").write_text("module NavoSmart.Backend\nNavoLanDiscovery 1.0 NavoLanDiscovery.qml\n")
    (backend / "NavoLanDiscovery.qml").write_text('''import QtQml
QtObject {
 property string protectedHost: ""
 property int serialPort: 8899
 property bool scanning: false
 property var devices: []
 function scan() { scanning = true }
 function stop() { scanning = false }
}''')
    (temp / "NavoVideoPlayer.qml").write_text('''import QtQuick
Item {
 property string streamUrl: ""
 property string protocol: "auto"
 property string status: "NO URL"
 property bool live: false
 signal videoError(string message)
 function start() {}
 function stop() {}
}''')
    (temp / "scene.qml").write_text('''import QtQuick
import QtQuick.Controls
ApplicationWindow {
 visible: true; width: 1024; height: 1000
 QtObject {
  id: state; objectName: "sonarState"
  property string host: ""
  property int port: 0
  property bool udp: false
  property bool connected: false
  property bool replayMode: false
  property bool dataAlive: false
  property string status: "OFFLINE"
  property int connects: 0
  property int stops: 0
  function connectSonar() { connects++; status = udp ? "UDP LISTENING • WAITING DATA" : "CONNECTING" }
  function disconnectSonar() { stops++; connected = false; dataAlive = false; status = "OFFLINE" }
 }
 NavoEthernetSettings {
  objectName: "settings"; width: parent.width; height: implicitHeight
  sonar: state
 }
}''')
    engine = QQmlApplicationEngine()
    engine.addImportPath(str(temp))
    engine.load(QUrl.fromLocalFile(str(temp / "scene.qml")))
    assert engine.rootObjects(), "Production QML failed to load"
    window = engine.rootObjects()[0]
    def find(name):
        from PySide6.QtCore import QObject
        obj = window.findChild(QObject, name)
        assert obj is not None, name
        return obj
    settings, state = find("settings"), find("sonarState")
    def settle(): QTest.qWait(70)
    def click(item):
        point = item.mapToScene(item.boundingRect().center()).toPoint()
        QTest.mouseClick(window, Qt.LeftButton, Qt.NoModifier, point)
        settle()
    def choices(item):
        result = []
        def visit(node):
            if node.property("text") in ("TCP", "UDP") and node.metaObject().indexOfProperty("selected") >= 0:
                result.append(node)
            for child in node.childItems(): visit(child)
        visit(item)
        return sorted(result, key=lambda obj: obj.property("index"))
    settle()
    connect = find("settingsSonarConnect")
    stop = find("settingsSonarStop")
    host, port = find("settingsSonarHost"), find("settingsSonarPort")
    selector = find("settingsSonarTransport")
    label = find("settingsSonarStatus")
    assert not connect.isEnabled()
    host.setProperty("text", "192.168.1.10")
    port.setProperty("text", "8899")
    settle()
    for width in (320, 480, 620, 749, 750, 1024, 1280, 1600):
        window.setWidth(width); settle()
        # Both actions must fit inside the sonar card, including vertically.
        panel = connect.parentItem().parentItem().parentItem()
        panelRect = panel.mapRectToItem(settings, panel.boundingRect())
        assert panelRect.left() >= 0 and panelRect.right() <= width + 0.1, (width, panelRect)
        for button in (connect, stop):
            rect = button.mapRectToItem(panel, button.boundingRect())
            assert rect.left() >= 9 and rect.right() <= panel.width()-9, (width, rect, panel.width())
            assert rect.top() >= 9 and rect.bottom() <= panel.height()-9, (width, rect, panel.height())
        assert connect.width() <= 108.1 and connect.height() <= 34.1
        assert settings.height() >= panel.mapToItem(settings, 0, panel.height()).y()
    if os.environ.get("NAVO_SETTINGS_CAPTURE"):
        window.setWidth(1024); settle()
        window.grabWindow().save(os.environ["NAVO_SETTINGS_CAPTURE"])
    window.setWidth(620); settle()
    tcp, udp = choices(selector)
    assert tcp.property("selected") and not udp.property("selected")
    click(udp)
    assert selector.property("checked") and udp.property("selected") and not tcp.property("selected")
    assert not state.property("udp"), "Selection must not silently switch the live transport"
    assert "TCP" in label.property("text") and "LIVE" not in label.property("text")
    click(udp)
    assert udp.property("selected") and not tcp.property("selected"), "Clicking selected segment must keep one selected"
    click(connect)
    assert state.property("udp") and state.property("connects") == 1
    assert "UDP LISTENING" in label.property("text") and "LIVE" not in label.property("text")
    state.setProperty("connected", True); state.setProperty("status", "RX DATA"); settle()
    assert "fără ecogramă validă" in label.property("text")
    state.setProperty("dataAlive", True); settle()
    assert label.property("text") == "Stare UDP: KOGGER LIVE"
    click(tcp)
    assert "UDP: KOGGER LIVE" in label.property("text"), "Show actual backend, not pending selection"
    click(connect)
    assert not state.property("udp") and state.property("connects") == 2
    state.setProperty("dataAlive", False); state.setProperty("status", "CONNECT TIMEOUT"); settle()
    assert "TIMEOUT" in label.property("text") and "LIVE" not in label.property("text")
    click(stop)
    assert state.property("stops") == 1 and "OFFLINE" in label.property("text")
    port.setProperty("text", "65536"); settle()
    assert not connect.isEnabled(), "Invalid port must disable Connect"
    port.setProperty("text", "8899"); host.setProperty("text", ""); settle()
    assert not connect.isEnabled(), "TCP needs a host"
    click(udp)
    assert connect.isEnabled(), "UDP listener permits an empty sender filter"
    camera = find("settingsCameraTransport")
    cameraTcp, cameraUdp = choices(camera)
    click(cameraUdp)
    assert cameraUdp.property("selected") and not cameraTcp.property("selected")
    assert selector.property("checked"), "Camera and sonar selections are independent"
    state.setProperty("replayMode", True); settle()
    assert "REDARE" in label.property("text") and "LIVE" not in label.property("text")
    state.setProperty("replayMode", False)
    click(connect) # Persist UDP and confirm it survives recreation of the settings page.
    assert state.property("udp") and state.property("connects") == 3
    QTest.qWait(1200) # QtCore.Settings batches disk writes.
    second = QQmlApplicationEngine()
    second.addImportPath(str(temp))
    second.load(QUrl.fromLocalFile(str(temp / "scene.qml")))
    assert second.rootObjects()
    from PySide6.QtCore import QObject
    restoredWindow = second.rootObjects()[0]
    restored = restoredWindow.findChild(QObject, "settingsSonarTransport")
    assert restored.property("checked"), "Saved UDP selection must survive restart"
    second.deleteLater()
    engine.deleteLater()
print("PASS production settings: 8 widths, exclusive TCP/UDP, actual vs pending state, live/replay/errors, connect/stop, port validation")
