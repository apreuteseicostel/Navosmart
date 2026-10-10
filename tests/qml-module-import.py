"""Exercise resource-module imports, including Qt's subdirectory qmldir redirect.

Filesystem UI tests miss ambiguity between a component's implicit module import
and Dashboard's explicit NavoSmart import when qmldir exports a JS helper.
"""
import os
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
from pathlib import Path
import subprocess
import tempfile
import PySide6
from PySide6.QtCore import QResource, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent, QQmlEngine

repo = Path(__file__).resolve().parent.parent
cmake = (repo / 'custom/CMakeLists.txt').read_text()
qml_files, resources = cmake.split('    QML_FILES\n', 1)[1].split('    RESOURCES\n', 1)
helper = 'qml/NavoBottomAnalysis.js'
assert helper in qml_files or helper in resources, 'Analysis helper must be packaged'
app = QGuiApplication([])
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    (root / 'main.qml').write_text('import QtQml\nimport NavoSmart 1.0\nProbe {}')
    (root / 'Probe.qml').write_text('''import QtQml
import NavoSmart 1.0
import "NavoBottomAnalysis.js" as Bottom
QtObject { property bool helperExecuted: Bottom.column([], 0, 10, 5).valid === false }
''')
    # Mirror qt_add_qml_module's generated module entries and QTP0004 redirect.
    (root / 'qmldir').write_text('module NavoSmart\nprefer :/qml/NavoSmart/\n'
        'Probe 1.0 qml/Probe.qml\n' +
        ('NavoBottomAnalysis 1.0 qml/NavoBottomAnalysis.js\n' if helper in qml_files else ''))
    (root / 'redirect').write_text('module NavoSmart\nprefer :/qml/NavoSmart/\n')
    entries = [('qmldir', root / 'qmldir'), ('qml/qmldir', root / 'redirect'),
               ('qml/Probe.qml', root / 'Probe.qml'), (helper, repo / 'custom' / helper)]
    qrc = root / 'module.qrc'
    qrc.write_text('<RCC><qresource prefix="/qml/NavoSmart">' + ''.join(
        f'<file alias="{alias}">{path}</file>' for alias, path in entries) + '</qresource></RCC>')
    resource = root / 'module.rcc'
    subprocess.run([str(Path(PySide6.__file__).parent / 'Qt/libexec/rcc'),
                    '--binary', str(qrc), '-o', str(resource)], check=True)
    assert QResource.registerResource(str(resource))
    engine = QQmlEngine()
    engine.addImportPath('qrc:/qml')
    component = QQmlComponent(engine, QUrl.fromLocalFile(str(root / 'main.qml')))
    assert component.status() == QQmlComponent.Ready, component.errors()
    instance = component.create()
    assert instance and instance.property('helperExecuted'), component.errors()
    print('PASS resource module imports and relative sonar analysis helper')
