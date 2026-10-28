"""Load actual GNSS and telemetry popups and check compact viewport/scroll gutters."""
import os
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
os.environ.setdefault('QT_QUICK_BACKEND', 'software')
from pathlib import Path
import tempfile, subprocess
import PySide6
from PySide6.QtCore import QObject, QResource, QUrl, QPointF, QMetaObject
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickItem
from PySide6.QtTest import QTest

repo = Path(__file__).resolve().parent.parent
source = (repo/'custom/qml/NavoDashboard.qml').read_text()
start = source.index('    Popup {\n        id: gnssDiagnostic')
end = source.index('\n    NavoStatusDetails {', start)
popup = source[start:end]
app = QGuiApplication([])
engine = QQmlApplicationEngine()
errors = []
engine.warnings.connect(lambda ws: errors.extend(str(w) for w in ws))
wrapper = '''import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "'''+QUrl.fromLocalFile(str(repo/'custom/qml')).toString()+'''"
ApplicationWindow {
 id: root; visible: true; width: 800; height: 480
 property var vehicle: ({gps:{count:{rawValue:13},lock:{rawValue:3},hdop:{rawValue:1.5},vdop:{rawValue:2.1}},coordinate:{isValid:true,latitude:52.308031,longitude:-1.936176,altitude:102.05},heading:{rawValue:47}})
 property bool linkAlive: true
 property color text: "#edf8ff"
 property color muted: "#a2bdd0"
 QtObject { id: gnssHeading
  property string headingSource: "H743 (rezervă)"
  property bool gpsYawValid: false
  property real gpsYawDeg: 0
  property int gpsYawAgeMs: 0
  property string headingDetail: "GPS are fix, dar orientarea GNSS duală nu este încă disponibilă."
 }
 NavoStatusDetails { id: telemetry; objectName: "telemetry"; viewportWidth: root.width; viewportHeight: root.height; linkAlive: true; battery: ({voltage:{rawValue:16.8},current:{rawValue:4.24},mahConsumed:{rawValue:956},percentRemaining:{rawValue:80}}) }
'''+popup+'}'
with tempfile.TemporaryDirectory() as directory:
    folder = Path(directory)
    qrc, resource = folder/'icons.qrc', folder/'icons.rcc'
    qrc.write_text('<RCC><qresource prefix="/qml/NavoSmart/icons">'+''.join(f'<file alias="{p.name}">{p}</file>' for p in (repo/'custom/icons').glob('*.svg'))+'</qresource></RCC>')
    subprocess.run([str(Path(PySide6.__file__).parent/'Qt/libexec/rcc'), '--binary', str(qrc), '-o', str(resource)], check=True)
    assert QResource.registerResource(str(resource))
    f = folder/'Test.qml'; f.write_text(wrapper)
    engine.load(QUrl.fromLocalFile(str(f)))
    assert engine.rootObjects(), errors
    window = engine.rootObjects()[0]
    gnss = window.findChild(QObject, 'gnssDiagnostic')
    telemetry = window.findChild(QObject, 'telemetry')
    for width, height in [(320,240),(640,360),(800,480),(1280,720)]:
        window.setWidth(width); window.setHeight(height)
        for panel in [gnss, telemetry]:
            if panel == telemetry: panel.setProperty('section', 'battery')
            QMetaObject.invokeMethod(panel, 'open'); QTest.qWait(80)
            for key, limit in [('x',width),('y',height)]:
                span = 'width' if key == 'x' else 'height'
                assert panel.property(key) >= 0
                assert panel.property(key)+panel.property(span) <= limit, (width,height,key)
            scroll_name, rows_name = ('gnssScroll','gnssRows') if panel == gnss else ('detailsScroll','detailsRows')
            scroll = window.findChild(QQuickItem, scroll_name)
            rows = window.findChild(QQuickItem, rows_name)
            bar = window.findChild(QQuickItem, 'gnssScrollBar' if panel == gnss else 'detailsScrollBar')
            assert bar
            bar.setProperty('active', True); QTest.qWait(30)
            bar_left = bar.mapToItem(scroll, QPointF()).x()
            assert rows.width() <= bar_left-9.9, (width,height, rows.width(),bar_left)
            if panel == gnss:
                # Dynamic help must remain scrollable inside the bounded panel.
                panel.setProperty('checkResult', 'GPS fără orientare duală. '*30); QTest.qWait(30)
                assert scroll.property('contentHeight') > scroll.height()
                scroll.setProperty('contentY', scroll.property('contentHeight')-scroll.height()); QTest.qWait(20)
                assert scroll.property('contentY') > 0
            if width == 800 and panel == gnss:
                window.grabWindow().save('/tmp/navo-gnss-compact.png')
            QMetaObject.invokeMethod(panel,'close'); QTest.qWait(30)
        print(f'PASS diagnostics fit {width}x{height}; active scrollbar has >=10px content clearance')
    telemetry.setProperty('section', 'temperature')
    QMetaObject.invokeMethod(telemetry, 'open'); QTest.qWait(60)
    scroll = window.findChild(QQuickItem, 'detailsScroll')
    rows = window.findChild(QQuickItem, 'detailsRows')
    bar = window.findChild(QQuickItem, 'detailsScrollBar')
    bar.setProperty('active', True)
    assert rows.width() <= bar.mapToItem(scroll, QPointF()).x()-9.9
    QMetaObject.invokeMethod(telemetry, 'close')
    print('PASS temperature uses the same protected scrollbar gutter')
    assert not errors, errors
