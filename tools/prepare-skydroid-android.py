#!/usr/bin/env python3
"""Install NAVO's Java adapter and exact vendor SDK into a pinned QGC checkout.
No vendor source is copied into this repository; the official AAR is hash checked.
"""
from pathlib import Path
import argparse
import hashlib
import shutil
import urllib.request

SDK_COMMIT = 'd9c6bcab8bb9993cd16f117c01a7601dce10ea6a'
SDK_SHA256 = 'e5977ba3292246bcee026defdb8563a18adc9d5573fdfb20a6880ee469f0fde2'
SDK_URL = f'https://gitee.com/skydroid/rcsdk-demo/raw/{SDK_COMMIT}/app/libs/rcsdk-v1.9.2.aar'
FACTORY_OLD = '''    case LinkConfiguration::TypeUdp:
        link = std::make_shared<UDPLink>(config);
        break;'''
FACTORY_NEW = '''    case LinkConfiguration::TypeUdp:
#ifdef Q_OS_ANDROID
        if (config->name() == NavoSkydroidLink::configurationName)
            link = std::make_shared<NavoSkydroidLink>(config);
        else
#endif
            link = std::make_shared<UDPLink>(config);
        break;'''

def once(path, old, new):
    text = path.read_text()
    if new in text:
        return
    if text.count(old) != 1:
        raise RuntimeError(f'Pinned QGC hook changed: {path}')
    path.write_text(text.replace(old, new, 1))

def prepare(qgc, aar):
    if hashlib.sha256(aar).hexdigest() != SDK_SHA256:
        raise RuntimeError('Skydroid SDK SHA256 mismatch; refusing unpinned dependency')
    root = Path(__file__).resolve().parents[1]
    java = root / 'custom/android/src/org/navosmart/connectivity/SkydroidBridge.java'
    target = qgc / 'android/src/org/navosmart/connectivity/SkydroidBridge.java'
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(java, target)
    shutil.copyfile(java.with_name("SkydroidDiagnostics.java"), target.with_name("SkydroidDiagnostics.java"))
    libs = qgc / 'android/libs'; libs.mkdir(parents=True, exist_ok=True)
    (libs / 'rcsdk-v1.9.2.aar').write_bytes(aar)
    # QGC already includes *.aar under android/libs. RCSDK uses Kotlin runtime.
    once(qgc / 'android/build.gradle', "    implementation 'androidx.core:core:1.13.1'",
         "    implementation 'androidx.core:core:1.13.1'\n    implementation 'org.jetbrains.kotlin:kotlin-stdlib:1.6.10'")
    manager = qgc / 'src/Comms/LinkManager.cc'
    once(manager, '#include "UDPLink.h"', '#include "UDPLink.h"\n#include "NavoSkydroidLink.h"')
    once(manager, FACTORY_OLD, FACTORY_NEW)

def main():
    ap = argparse.ArgumentParser(); ap.add_argument('qgc', type=Path)
    ap.add_argument('--sdk-file', type=Path, help='Offline official AAR, still SHA256 verified')
    args = ap.parse_args()
    if args.sdk_file:
        aar = args.sdk_file.read_bytes()
    else:
        error = None
        for _ in range(3):
            try:
                with urllib.request.urlopen(SDK_URL, timeout=45) as response:
                    aar = response.read(10 * 1024 * 1024 + 1)
                if len(aar) > 10 * 1024 * 1024:
                    raise RuntimeError('Unexpected SDK size')
                break
            except Exception as exc:
                error = exc
        else:
            raise RuntimeError(f'Cannot download pinned official RCSDK: {error}')
    prepare(args.qgc, aar)
    print(f'PASS Skydroid RCSDK 1.9.2 {SDK_COMMIT}: SHA256 verified; QGC factory/Java installed')

if __name__ == '__main__':
    main()
