#!/usr/bin/env python3
"""Install pinned official FPV Player AARs and NAVO's own adapter, without demo source."""
from pathlib import Path
import argparse,hashlib,shutil,subprocess,tempfile
COMMIT='b4974344020b85d7eafccdeeec2acc419be453dd'
ARTIFACTS={
 'fpvplayer-v3.3.9.aar':'f62dfefdce956b98edf9bd3d28d7b8db2972d60c48847fb92d270880607e9f97',
 'sky-ijkplayer-v1.1.aar':'6799bd2bc62b11785b7cedcb4dba9eee22a78731ad4e93128687db042454f693'
}
def prepare(qgc,sdk_dir=None):
 libs=qgc/'android/libs';libs.mkdir(parents=True,exist_ok=True)
 # Verify everything before changing the checkout; don't downgrade the RCSDK to the demo's 1.8.3.
 verified={}
 with tempfile.TemporaryDirectory() as directory:
  checkout=Path(directory)
  if not sdk_dir:
   subprocess.run(['git','init','-q',str(checkout)],check=True)
   subprocess.run(['git','-C',str(checkout),'remote','add','origin','https://gitee.com/skydroid/fpv-player-demo.git'],check=True)
   subprocess.run(['git','-C',str(checkout),'fetch','--depth','1','origin',COMMIT],check=True,timeout=180)
  for name,digest in ARTIFACTS.items():
   data=(sdk_dir/name).read_bytes() if sdk_dir else subprocess.check_output(['git','-C',str(checkout),'show',f'{COMMIT}:app/libs/{name}'])
   if len(data)>100*1024*1024 or hashlib.sha256(data).hexdigest()!=digest:raise RuntimeError('FPV SHA256 mismatch: '+name)
   verified[name]=data
 for name,data in verified.items():(libs/name).write_bytes(data)
 source=Path(__file__).resolve().parents[1]/'custom/android/src/org/navosmart/video/SkydroidVideoBridge.java'
 target=qgc/'android/src/org/navosmart/video/SkydroidVideoBridge.java';target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
 print('PASS pinned official FPV Player 3.3.9 / IJK 1.1 AAR hashes; NAVO adapter installed')
if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('qgc',type=Path);ap.add_argument('--sdk-dir',type=Path);args=ap.parse_args();prepare(args.qgc,args.sdk_dir)
