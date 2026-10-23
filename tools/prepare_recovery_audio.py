"""Prepare per-vehicle recorded starter substitutes and circular stereo wind.
Requires the public BigSoundBank source WAVs under assets_src/vehicle_audio.
"""
import hashlib,json,subprocess,wave
from pathlib import Path
import numpy as np
from prepare_engine_audio import decode,write,DEST,RATE,ROOT

STARTS=[('scout','0534',0,1.5),('cargo','0967',0,1.5),('heavy','0896',0,2.2),('niva','0557',3.1,4.8),('lada2107','0966',2,3.5),('lada2106','0872',8,10),('uaz_expedition','0557',3.0,4.7),('uaz452','0872',8.2,10.15),('uaz469','0966',1.9,3.5)]
SOURCES={
 '0904':('forest-wind-in-the-trees','Wind in the Trees'),
 '0967':('big-diesel-engine','Kia Carnival 2.9 diesel'),
 '0557':('cars-interior-off','Unidentified car interior'),
 '0872':('car-difficult-start','Peugeot 106'),
 '0896':('ford-courier-engine','Ford Courier'),
 '0534':('ac-cobra-engine','AC Cobra 427'),
 '0966':('small-gasoline-engine','Peugeot 107'),
}
manifest={'notice':'All starter assignments are explicitly disclosed substitutes. Nine vehicle-specific edits use six different source recordings. No authentic Lada/Jeep/UAZ start is claimed.','sources':{},'files':[]}
for id,(slug,title)in SOURCES.items():
 manifest['sources'][id]={'url':f'https://bigsoundbank.com/{slug}-s{id}.html','download':f'https://bigsoundbank.com/UPLOAD/bwf-en/{id}.wav','identity':title,'author':'Joseph Sardin','license':'CC0'}
cache={}
for vehicle,id,start,end in STARTS:
 if id not in cache:cache[id]=decode(id)
 f=write('start_'+vehicle,cache[id][int(start*RATE):int(end*RATE)],False)
 f.update(vehicle=vehicle,source=id,cut=[start,end]);manifest['files'].append(f)
# Keep stereo forest wind, with 0.8s circular overlap rather than silent joins.
raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(ROOT/'assets_src/vehicle_audio/0904.wav'),'-ss','12','-t','55','-ar',str(RATE),'-ac','2','-f','f32le','-'])
x=np.frombuffer(raw,dtype='<f4').reshape(-1,2).copy();xf=int(RATE*.8)
k=(.5-.5*np.cos(np.linspace(0,np.pi,xf)))[:,None]
x-=x.mean(0);y=x[xf:].copy();y[-xf:]=y[-xf:]*(1-k)+x[:xf]*k
y*=min(.2/max(np.sqrt(np.mean(y*y)),1e-9),.85/max(abs(y).max(),1e-9))
temp=ROOT/'assets_src/vehicle_audio/wind_prepared.wav'
with wave.open(str(temp),'wb')as f:
 f.setnchannels(2);f.setsampwidth(2);f.setframerate(RATE);f.writeframes((y*32767).astype('<i2').tobytes())
output=ROOT/'assets/audio/wind_trees.ogg'
subprocess.run(['ffmpeg','-v','error','-y','-i',str(temp),'-c:a','vorbis','-strict','experimental','-q:a','5',str(output)],check=True)
manifest['files'].append({'file':'../wind_trees.ogg','source':'0904','cut':[12,67],'processing':'0.8s circular crossfade, DC removal, stereo level match, Vorbis','sha256':hashlib.sha256(output.read_bytes()).hexdigest()})
(DEST/'RECOVERY_SOURCES.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Prepared nine recorded starter edits and stereo looping wind.')
