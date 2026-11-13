#!/usr/bin/env python3
"""Install NAVO's Java adapter and exact vendor SDK into a pinned QGC checkout.
No vendor source is copied into this repository; the official AAR is hash checked.
"""
from pathlib import Path
import argparse
import hashlib
import shutil
import subprocess
import tempfile
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

def download_official_sdk():
    """Try the pinned vendor raw URL, then fetch the same commit via git.

    Never accept an unpinned mirror or skip the SHA256 check in prepare().
    """
    errors = []
    for attempt in range(3):
        try:
            with urllib.request.urlopen(SDK_URL, timeout=45) as response:
                data = response.read(10 * 1024 * 1024 + 1)
            if len(data) > 10 * 1024 * 1024:
                raise RuntimeError('Unexpected SDK size')
            if hashlib.sha256(data).hexdigest() != SDK_SHA256:
                raise RuntimeError('Downloaded SDK hash mismatch')
            return data
        except Exception as exc:
            errors.append(f'raw attempt {attempt + 1}: {type(exc).__name__}: {exc}')

    # The Gitee raw endpoint has returned truncated responses on CI runners.
    # The official Git transport already works for our pinned FPV SDK.
    try:
        with tempfile.TemporaryDirectory(prefix='navo-rcsdk-') as directory:
            subprocess.run(['git', 'init', '-q', directory], check=True, timeout=20)
            subprocess.run(['git', '-C', directory, 'remote', 'add', 'origin',
                            'https://gitee.com/skydroid/rcsdk-demo.git'], check=True, timeout=20)
            subprocess.run(['git', '-C', directory, 'fetch', '--depth', '1',
                            'origin', SDK_COMMIT], check=True, timeout=180,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            data = subprocess.check_output(['git', '-C', directory, 'show',
                                            f'{SDK_COMMIT}:app/libs/rcsdk-v1.9.2.aar'],
                                           timeout=30)
            if len(data) > 10 * 1024 * 1024:
                raise RuntimeError('Unexpected SDK size from pinned git commit')
            if hashlib.sha256(data).hexdigest() != SDK_SHA256:
                raise RuntimeError('Pinned git SDK hash mismatch')
            return data
    except Exception as exc:
        errors.append(f'pinned git fallback: {type(exc).__name__}: {exc}')
    raise RuntimeError('Cannot download pinned official RCSDK: ' + '; '.join(errors))

def main():
    ap = argparse.ArgumentParser(); ap.add_argument('qgc', type=Path)
    ap.add_argument('--sdk-file', type=Path, help='Offline official AAR, still SHA256 verified')
    args = ap.parse_args()
    if args.sdk_file:
        aar = args.sdk_file.read_bytes()
    else:
        aar = download_official_sdk()
    prepare(args.qgc, aar)
    print(f'PASS Skydroid RCSDK 1.9.2 {SDK_COMMIT}: SHA256 verified; QGC factory/Java installed')

if __name__ == '__main__':
    main()
