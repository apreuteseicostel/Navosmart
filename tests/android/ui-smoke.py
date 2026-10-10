"""Exercise named navigation controls with no connected vehicle in CI."""
import subprocess, time, re, xml.etree.ElementTree as ET
from pathlib import Path
out=Path('build/screenshots');out.mkdir(parents=True,exist_ok=True)
nav=['HARTA','SONAR','SONAR PRO','MISIUNI','PUNCTE PESCUIT','BALȚILE MELE','CAMERA','3D','NĂDIRE','SIGURANȚĂ','SETARI']
def adb(*args):
 return subprocess.check_output(['adb','-s','emulator-5554',*args],timeout=25)
def snapshot():
 adb('shell','uiautomator','dump','/sdcard/navo-ui.xml')
 xml=adb('shell','cat','/sdcard/navo-ui.xml')
 Path('build/navo-ui.xml').write_bytes(xml)
 return ET.fromstring(xml).iter('node')
def locate(name,navigation=False):
 nodes=list(snapshot());matches=[]
 bounds=[list(map(int,re.findall(r'-?\\d+',node.get('bounds','')))) for node in nodes]
 screen_width=max((b[2] for b in bounds if len(b)==4),default=0)
 # The NAVO sidebar is a 64/72 px rail. Qt's Android accessibility
 # resource-id is not guaranteed to expose the inline QML component name.
 rail_limit=min(112,max(72,int(screen_width*.12)))
 for node in nodes:
  if name not in [node.get('text'),node.get('content-desc')]:continue
  b=list(map(int,re.findall(r'-?\\d+',node.get('bounds',''))))
  if len(b)!=4 or b[0]<0 or b[1]<0 or b[2]<=b[0] or b[3]<=b[1]:continue
  if navigation and (b[0]>=rail_limit or b[2]>rail_limit+12 or b[3]-b[1]<28):continue
  matches.append((node.get('clickable')=='true',b))
 if matches:
  _,b=max(matches,key=lambda m:m[0]);return ((b[0]+b[2])//2,(b[1]+b[3])//2)
 return None
def click(name,scroll=False):
 for n in range(8):
  pos=locate(name,scroll)
  if pos:
   adb('shell','input','tap',str(pos[0]),str(pos[1]));time.sleep(1.2);return
  if not scroll:break
  # Scroll only the navigation rail, never map/mission controls.
  xml=ET.parse('build/navo-ui.xml');bounds=[list(map(int,re.findall(r'-?\d+',x.get('bounds','')))) for x in xml.iter('node')]
  bounds=[b for b in bounds if len(b)==4];h=max(b[3] for b in bounds);w=max(b[2] for b in bounds);x=max(20,int(w*.035))
  y0,y1=(int(h*.85),int(h*.30)) if name!='HARTA' else (int(h*.30),int(h*.85))
  adb('shell','input','swipe',str(x),str(y0),str(x),str(y1),'500');time.sleep(.2)
 raise RuntimeError('Navigation control unavailable: '+name)
for i,name in enumerate(nav):
 click(name,True)
 if not locate('Pagina '+name):raise RuntimeError('Page did not load: '+name)
 (out/f'page-{i:02d}.png').write_bytes(adb('exec-out','screencap','-p'))
 if name=='SONAR PRO':
  click('Deschide / închide meniul Sonar PRO')
  (out/'sonar-pro-menu.png').write_bytes(adb('exec-out','screencap','-p'))
  click('Deschide / închide meniul Sonar PRO')
  click('Ieșire din Sonar PRO')
 print('PASS navigation:',name,flush=True)
click('HARTA',True)
(out/'dashboard-after-navigation.png').write_bytes(adb('exec-out','screencap','-p'))
