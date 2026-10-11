"""Drive the CI-only installed APK through real replay, maps and process restart.

Requires a disposable rootable emulator. Never connects a vehicle or installs
mock backends. ARM64 release builds keep the acceptance switch disabled.
"""
import hashlib, json, re, subprocess, sys, time
import xml.etree.ElementTree as ET
from pathlib import Path

package, activity, fixture = sys.argv[1:4]
out = Path('build/acceptance'); out.mkdir(parents=True, exist_ok=True)
screens = Path('build/screenshots'); screens.mkdir(parents=True, exist_ok=True)
def adb(*args):
    return subprocess.check_output(['adb', '-s', 'emulator-5554', *args], timeout=40)
def shell(*args):
    return adb('shell', *args)

assert hashlib.sha256(Path(fixture).read_bytes()).hexdigest() == '1ff5e23abbdd37e31eeacd7875c4e8a457ccb927641e47ea77c861151ab2ace0', 'Kogger fixture hash mismatch'
log = adb('logcat', '-d').decode(errors='replace')
directories = re.findall(r'NAVO_ACCEPTANCE_DIR:\s*(/data/[^\s\r\n]+)', log)
assert directories, 'Acceptance build did not advertise its private directory'
directory = directories[-1].strip('"')
assert package in directory and re.fullmatch(r'/data/[A-Za-z0-9_./-]+', directory), 'Unexpected private directory'
adb('root'); adb('wait-for-device')
owner = shell('stat', '-c', '%u:%g', directory).decode().strip()
assert re.fullmatch(r'\d+:\d+', owner), 'Private directory owner missing'
shell('am', 'force-stop', package)
adb('push', fixture, directory + '/00028_DownView.klf')
shell('chown', owner, directory + '/00028_DownView.klf')
shell('chmod', '600', directory + '/00028_DownView.klf')
shell('restorecon', directory + '/00028_DownView.klf')

def tap_saved_spot_action(label):
    for attempt in range(5):
        shell('uiautomator','dump','/sdcard/navo-spot-ui.xml')
        xml=ET.fromstring(shell('cat','/sdcard/navo-spot-ui.xml'))
        (out/'saved-spot-ui.xml').write_bytes(ET.tostring(xml))
        bounds=[list(map(int,re.findall(r'-?\d+',node.get('bounds','')))) for node in xml.iter('node')]
        bounds=[b for b in bounds if len(b)==4]
        width=max(b[2] for b in bounds);height=max(b[3] for b in bounds)
        for node in xml.iter('node'):
            if label not in (node.get('text'),node.get('content-desc')):continue
            b=list(map(int,re.findall(r'-?\d+',node.get('bounds',''))))
            if len(b)==4 and 0<=b[0]<b[2]<=width and 0<=b[1]<b[3]<=height and b[3]-b[1]>=20:
                shell('input','tap',str((b[0]+b[2])//2),str((b[1]+b[3])//2));return
        shell('input','swipe',str(width//2),str(int(height*.72)),str(width//2),str(int(height*.42)),'400')
        time.sleep(.3)
    raise RuntimeError('Installed saved-point action unavailable: '+label)

def run_phase(config):
    phase = config['phase']
    request = out / (phase + '-request.json'); request.write_text(json.dumps(config))
    shell('am', 'force-stop', package)
    shell('rm', '-f', directory + '/navo-acceptance-report.json')
    remote = directory + '/navo-acceptance-request.json'
    adb('push', str(request), remote); shell('chown', owner, remote)
    shell('chmod', '600', remote); shell('restorecon', remote)
    shell('am', 'start', '-W', '-n', package + '/' + activity)
    started = time.monotonic(); captured = set(); interactions=set(); previous_stage = None; last_progress_capture = 0
    while time.monotonic() - started < 750:
        time.sleep(1)
        if not shell('pidof', package).strip():
            raise RuntimeError('Installed application exited during ' + phase)
        try:
            report = json.loads(shell('cat', directory + '/navo-acceptance-report.json'))
        except (subprocess.CalledProcessError, json.JSONDecodeError):
            if time.monotonic()-started>45:
                raise RuntimeError("Installed acceptance driver produced no report")
            continue
        (out / (phase + '-report.json')).write_text(json.dumps(report, indent=2))
        stage = report.get('stage')
        if stage != previous_stage:
            print('Installed acceptance:', phase, stage, flush=True); previous_stage = stage
        if stage == 'replay' and time.monotonic()-last_progress_capture > 30:
            print('Replay progress:', {key: report.get(key) for key in ('replayPosition','replaySize','replayActive','processedColumns','nativeCapacityFull','replayMappingSamples','nativeSurfaceIndices')}, flush=True)
            (screens / ('acceptance-' + phase + '-replay-progress.png')).write_bytes(adb('exec-out','screencap','-p'))
            last_progress_capture = time.monotonic()
        if stage not in captured and (stage == 'sonar-evidence' or report.get('sceneReady')):
            (screens / ('acceptance-' + phase + '-' + stage + '.png')).write_bytes(adb('exec-out', 'screencap', '-p'))
            captured.add(stage)
        if phase=='spots' and stage not in interactions:
            if stage.startswith('spots-pin-') and report.get('sceneReady') and report.get('spotPin'):
                pin=report['spotPin'];long_press=stage.endswith('-bait')
                print('Saved point gesture:',stage,'hold' if long_press else 'tap',pin,flush=True)
                if long_press:shell('input','swipe',str(pin['x']),str(pin['y']),str(pin['x']),str(pin['y']),'1500')
                else:shell('input','tap',str(pin['x']),str(pin['y']))
                interactions.add(stage)
            elif stage.startswith('spots-action-'):
                labels={'navigation':'NAVIGHEAZĂ LA PUNCT','bait':'NĂDIRE LA PUNCT','scan':'SCANARE ÎN JURUL PUNCTULUI'}
                tap_saved_spot_action(labels[stage.removeprefix('spots-action-')]);interactions.add(stage)
        if report.get('status') == 'failed':
            (screens / ('acceptance-' + phase + '-failed.png')).write_bytes(adb('exec-out','screencap','-p'))
            raise RuntimeError(report.get('error'))
        if report.get('status') == 'passed':
            expected={'spots-action-navigation','spots-action-bait','spots-action-scan'} if phase=='spots' else {'3d', 'native-map' if phase == 'record' else 'restored-map'}
            assert expected <= captured, 'Rendered scene evidence missing'
            return report
    raise RuntimeError('No terminal installed acceptance report for ' + phase)

try:
    recorded = run_phase({'phase': 'record'})
    restored = run_phase({'phase': 'restore', 'replayId': recorded['replayId'], 'liveId': recorded['liveId'], 'samples': recorded['samples']})
    assert restored.get('areaResumeConfirmed'), 'Area Scan resume not verified'
    spots=run_phase({'phase':'spots','liveId':recorded['liveId']})
    assert all(spots.get(key) for key in ['savedSpotNavigationVerified','savedSpotBaitVerified','savedSpotScanVerified','savedSpotDisconnectedStartBlocked']), 'Saved point actions not verified'
    print('PASS installed x86_64 APK: original Kogger replay, Sonar PRO, native QtLocation surface, 3D mesh, separate lake save, forced process restart Area Scan resume and saved-point long press/navigation/bait/scan with disconnected START blocked. No hardware acceptance.', flush=True)
finally:
    (out / 'logcat.txt').write_bytes(adb('logcat', '-d'))
    shell('am', 'force-stop', package)
    shell('rm', '-f', directory + '/navo-acceptance-request.json')
