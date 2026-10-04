"""Package the CI-built Qt test runner for replay beside an uploaded fixture."""
import pathlib, subprocess, shutil, tarfile
build=pathlib.Path('/tmp/navo-replay'); base=pathlib.Path('/tmp/navo-qt-runtime')
core=base/'core';ui=base/'ui'
for folder in [core/'lib',core/'plugins/platforms',ui/'lib',ui/'plugins/imageformats',ui/'qml']:folder.mkdir(parents=True,exist_ok=True)
seen=set()
def deps(file,dest):
    output=subprocess.check_output(['ldd',str(file)],text=True)
    for line in output.splitlines():
        if '=>' not in line:continue
        path=line.split('=>',1)[1].strip().split(' ',1)[0]
        if not path.startswith('/'):continue
        name=pathlib.Path(path).name
        if name.startswith(('libc.so','libm.so','libpthread.so','libdl.so','libstdc++','libgcc_s')):continue
        if name in seen:continue
        seen.add(name);shutil.copy2(path,dest/name,follow_symlinks=True)
for executable,folder in [('navo-kogger-replay',core),('navo-sonar-ui-replay',ui)]:
    source=build/executable;shutil.copy2(source,folder/executable);deps(source,folder/'lib')
plugins=pathlib.Path('/usr/lib/x86_64-linux-gnu/qt6/plugins')
for category,name,folder in [('platforms','libqoffscreen.so',core),('imageformats','libqsvg.so',ui)]:
    source=plugins/category/name;shutil.copy2(source,folder/'plugins'/category/name);deps(source,folder/'lib')
qml=pathlib.Path('/usr/lib/x86_64-linux-gnu/qt6/qml')
shutil.copytree(qml,ui/'qml',dirs_exist_ok=True,symlinks=False)
for plugin in qml.rglob('*.so'):deps(plugin,ui/'lib')
for folder in [core,ui]:
    output=base/(folder.name+'.tar.gz')
    with tarfile.open(output,'w:gz') as archive:archive.add(folder,arcname=folder.name)
    print(output,output.stat().st_size)
