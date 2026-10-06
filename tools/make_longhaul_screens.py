from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import math
root=Path(__file__).resolve().parents[1]
out=root/'assets'/'cockpit'
out.mkdir(parents=True,exist_ok=True)
font_path=str(root/'assets'/'fonts'/'VT323-Regular.ttf')
f=ImageFont.truetype(font_path,28);small=ImageFont.truetype(font_path,22);big=ImageFont.truetype(font_path,38)
for kind in ['nav','fuel','drive','radar','comms','power','status','dock']:
 amber=kind in ['fuel','drive','power','status'];fg='#e5b34f' if amber else '#8bdd98';dim='#5e4b27' if amber else '#254c38';bg='#14180e' if amber else '#071c15'
 im=Image.new('RGB',(512,384),bg);d=ImageDraw.Draw(im)
 d.rounded_rectangle((9,9,503,375),radius=14,outline=dim,width=2)
 d.text((25,20),{'nav':'NAV / ROUTE COMPUTER','fuel':'FUEL / RESERVES','drive':'DRIVE / DIAGNOSTICS','radar':'PROXIMITY / RADAR','comms':'COMMS / CHANNEL 04','power':'POWER DISTRIBUTION','status':'LIFE SUPPORT','dock':'DOCKING / ALIGNMENT'}[kind],font=f,fill=fg)
 d.line((24,57,488,57),fill=dim,width=2)
 if kind=='nav':
  for x in range(40,490,40):d.line((x,80,x,295),fill=dim)
  for y in range(80,296,40):d.line((32,y,480,y),fill=dim)
  pts=[(65,260),(150,215),(230,228),(320,145),(436,97)];d.line(pts,fill=fg,width=3)
  for x,y in pts:d.rectangle((x-7,y-7,x+7,y+7),outline=fg,width=2)
  d.text((30,310),'CERES > THARSIS',font=f,fill=fg);d.text((30,342),'GRID 024 / 003 / -068',font=small,fill=fg)
 elif kind in ['fuel','power','status']:
  names={'fuel':['H2','O2','RCS'],'power':['DRIVE','HAB','AUX'],'status':['AIR','TEMP','H2O']}[kind]
  for j,n in enumerate(names):
   x=55+j*150
   for k in range(10): d.rectangle((x,266-k*17,x+62,277-k*17),fill=fg if k<9-j else dim)
   d.text((x,295),n,font=f,fill=fg);d.text((x,76),str(92-j*8)+'%',font=f,fill=fg)
  d.text((30,345),'NOMINAL / SYSTEM READY',font=small,fill=fg)
 elif kind=='drive':
  d.rectangle((172,135,332,250),outline=fg,width=3);d.rectangle((108,150,166,240),outline=fg,width=3)
  for x in [210,300]:
   d.rectangle((x,102,x+40,130),outline=fg,width=3);d.rectangle((x,255,x+40,295),outline=fg,width=3)
  for x,y in [(172,158),(332,214),(245,135)]:d.line((x,y,x+55,y-45),fill=fg,width=2)
  d.text((30,315),'COOLANT 100%   DRIVE 100%',font=small,fill=fg);d.text((30,345),'NO FAULTS / SERVICE READY',font=small,fill=fg)
 elif kind in ['radar','dock']:
  for r in [40,85,125]:d.ellipse((256-r,218-r,256+r,218+r),outline=dim if r==85 else fg,width=2)
  d.line((100,218,412,218),fill=dim,width=2);d.line((256,80,256,355),fill=dim,width=2)
  if kind=='radar':
   d.line((256,218,326,112),fill=fg,width=3)
   for x,y in [(180,144),(290,230),(335,185)]:d.rectangle((x-4,y-4,x+4,y+4),fill=fg)
  else:
   d.rectangle((230,195,282,241),outline=fg,width=3);d.text((22,340),'REL V 000.0 / HOLD',font=small,fill=fg)
 else:
  for j,t in enumerate(['04  CERES CONTROL','12  DOCK SERVICES','16  HAULER NETWORK','20  EMERGENCY']):
   y=91+j*52;d.rectangle((28,y+4,42,y+18),fill=fg if j==0 else dim);d.text((58,y),t,font=f,fill=fg if j==0 else dim)
  d.text((30,325),'RX READY / STANDBY',font=f,fill=fg)

 im.save(out/(kind+'.png'))
