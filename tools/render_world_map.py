"""Render an exact overhead preview from tools/export_world_map.gd output."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json
root = Path(__file__).resolve().parents[1]
d = json.loads((root/'build/world-map.json').read_text())
n = len(d['heights'])
base = Image.new('RGB', (n,n))
for z,row in enumerate(d['heights']):
    for x,h in enumerate(row):
        if h < -2.4:
            c=(35,104,126)
        else:
            t=max(0,min(h/180,1))
            c=tuple(int(a+(b-a)*t) for a,b in zip((55,98,65),(166,154,130)))
            shade=max(.70,min(1.2,1+(row[max(x-1,0)]-h)*.018))
            c=tuple(min(255,int(v*shade)) for v in c)
        base.putpixel((x,z),c)
side=850; ox=40; oy=110
im=Image.new('RGB',(1200,1030),(18,29,29));im.paste(base.resize((side,side),Image.Resampling.BICUBIC),(ox,oy))
g=ImageDraw.Draw(im)
def font(n):
    return ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',n)
def point(x,z): return (ox+(x+1024)/2048*side,oy+(z+1024)/2048*side)
g.text((40,30),'DAĞ YOLLARI',font=font(32),fill=(241,239,224))
g.text((40,72),'2048 × 2048 m  ·  4.19 km²  ·  Asfalt marşrut: 6.1 km',font=font(20),fill=(184,202,190))
for name,color,width in [('road',(235,220,174),4),('trail',(226,134,65),4)]:
    g.line([point(x,z) for x,z in d[name]],fill=color,width=width,joint='curve')
for i,(label,x,z) in enumerate(d['places']):
    px,py=point(x,z)
    g.ellipse((px-9,py-9,px+9,py+9),fill=(247,181,66),outline=(25,35,30),width=2)
    g.text((px-4,py-7),str(i+1),font=font(12),fill=(20,30,28))
    g.text((920,190+i*74),str(i+1)+'. '+label,font=font(19),fill=(236,233,217))
g.text((920,125),'MARŞRUTLAR',font=font(21),fill=(240,237,222))
g.line((920,620,963,620),fill=(235,220,174),width=4)
g.text((975,608),'Asfalt',font=font(18),fill=(236,233,217))
g.line((920,667,963,667),fill=(226,134,65),width=4)
g.text((975,655),'Palçıqlı yol',font=font(18),fill=(236,233,217))
g.text((920,750),'M — oyun xəritəsi',font=font(18),fill=(100,208,198))
g.text((40,983),'Prosedur xəritənin dəqiq üst görünüşü · Oyundan ekran görüntüsü deyil',font=font(17),fill=(161,184,173))
im.save(root/'docs/world-map-preview.png')
print(root/'docs/world-map-preview.png')
