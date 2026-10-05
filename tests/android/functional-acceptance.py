"""Drive the CI-only installed APK through real replay, maps and process restart.

Requires a disposable rootable emulator. Never connects a vehicle or installs
mock backends. ARM64 release builds keep the acceptance switch disabled.
"""
import hashlib, json, re, subprocess, sys, time
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

def run_phase(config):
    phase = config['phase']
    request = out / (phase + '-request.json'); request.write_text(json.dumps(config))
    shell('am', 'force-stop', package)
    shell('rm', '-f', directory + '/navo-acceptance-report.json')
    remote = directory + '/navo-acceptance-request.json'
    adb('push', str(request), remote); shell('chown', owner, remote)
    shell('chmod', '600', remote); shell('restorecon', remote)
    shell('am', 'start', '-W', '-n', package + '/' + activity)
    started = time.monotonic(); captured = set(); previous_stage = None
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
        if stage not in captured and (stage == 'sonar-evidence' or report.get('sceneReady')):
            (screens / ('acceptance-' + phase + '-' + stage + '.png')).write_bytes(adb('exec-out', 'screencap', '-p'))
            captured.add(stage)
        if report.get('status') == 'failed':
            raise RuntimeError(report.get('error'))
        if report.get('status') == 'passed':
            assert {'3d', 'native-map' if phase == 'record' else 'restored-map'} <= captured, 'Rendered scene evidence missing'
            return report
    raise RuntimeError('No terminal installed acceptance report for ' + phase)

try:
    recorded = run_phase({'phase': 'record'})
    restored = run_phase({'phase': 'restore', 'replayId': recorded['replayId'], 'liveId': recorded['liveId'], 'samples': recorded['samples']})
    assert restored.get('areaResumeConfirmed'), 'Area Scan resume not verified'
    print('PASS installed x86_64 APK: original Kogger replay, Sonar PRO, native QtLocation surface, 3D mesh, separate lake save, forced process restart and Area Scan resume. No hardware acceptance.', flush=True)
finally:
    (out / 'logcat.txt').write_bytes(adb('logcat', '-d'))
    shell('am', 'force-stop', package)
    shell('rm', '-f', directory + '/navo-acceptance-request.json')
