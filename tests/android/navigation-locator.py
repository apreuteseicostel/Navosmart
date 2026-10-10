"""Recorded Android #832 geometry: physical bounds exceed a 112px rail.

Run the production locator without adb. Check density, status-label duplicates
and clipped scroll entries; actual page navigation is still tested on emulator.
"""
import ast
import re
from pathlib import Path
import xml.etree.ElementTree as ET

source=Path(__file__).with_name('ui-smoke.py').read_text()
locator=next(n for n in ast.parse(source).body if isinstance(n,ast.FunctionDef) and n.name=='locate')
code=compile(ast.Module(body=[locator],type_ignores=[]),str(Path(__file__).with_name('ui-smoke.py')),'exec')
for scale in [.5,1,2]:
 def bounds(x0,y0,x1,y1):
  return f'[{int(x0*scale)},{int(y0*scale)}][{int(x1*scale)},{int(y1*scale)}]'
 # Dimensions/control widths taken from #832's UIAutomator evidence.
 nodes=[ET.Element('node',{'bounds':bounds(0,0,2400,1080)})]
 for name,y in [('HARTA',180),('SONAR',288),('SONAR PRO',396),('MISIUNI',504)]:
  nodes.append(ET.Element('node',{'content-desc':name,'resource-id':'QGCApplication.MainWindow_QMLTYPE_337.NavButton',
   'bounds':bounds(21,y,146,y+99),'clickable':'true'}))
 nodes.append(ET.Element('node',{'content-desc':'SONAR','resource-id':'QGCApplication.Label',
  'bounds':bounds(2210,503,2298,528),'clickable':'false'}))
 env={'re':re,'snapshot':lambda:list(nodes)};exec(code,env)
 assert env['locate']('SONAR',True)==(int((int(21*scale)+int(146*scale))/2),int((int(288*scale)+int(387*scale))/2))
 nodes[2].set('bounds',bounds(21,0,146,41))
 assert env['locate']('SONAR',True) is None, 'Clipped entry must scroll into view'
 nodes[2].set('bounds',bounds(21,288,146,387));nodes[2].set('resource-id','Qt.Button')
 assert env['locate']('SONAR',True) is not None, 'Fallback must respect display density'
print('PASS Android navigation locator at three densities, clipped controls and duplicate status label')
