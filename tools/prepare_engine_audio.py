"""Offline recorded loop preparation: Python3 + numpy + ffmpeg.
Sources are freely downloadable BigSoundBank WAVs (CC0). Vehicle assignments
are substitutes; source identities and edits remain in the small JSON manifest.
No source is renamed to suggest an authentic Lada/Jeep recording.
"""
from pathlib import Path
import hashlib,json,subprocess,wave
import numpy as np

ROOT=Path(__file__).resolve().parent.parent
SOURCE=ROOT/'assets_src/vehicle_audio'
DEST=ROOT/'assets/audio/engines'
RATE=44100
SOURCES={
 '0534':('ac-cobra-engine','AC Cobra 427','Joseph Sardin'),
 '1145':('truck-engine','Iveco Daily 3.0 40C14 HPI','Joseph Sardin'),
 '1443':('truck-engine-2','unidentified truck','Joseph Sardin'),
 '0291':('car-engine-2','unidentified retro car #2','DenisChardonnet'),
 '0966':('small-gasoline-engine','Peugeot 107 1.0 petrol','Joseph Sardin'),
 '0290':('motor-car-1','unidentified retro car #1','DenisChardonnet'),
 '1147':('truck-engine-big-accelerations','Iveco Daily 3.0 40C14 HPI accelerations','Joseph Sardin'),
 '1284':('bike-on-gravel-mtb-1','MTB rolling on gravel (foley substitute)','Joseph Sardin'),
 '0495':('steps-in-the-mud','liquid mud footsteps (foley substitute)','Joseph Sardin'),
}
# Source start/end seconds. Short old-car captures have no isolated idle:
# these loops are designed substitutes, not claimed measured RPM sweeps.
CUTS={
 'scout': [('0534',14,18),('0534',3,6),('0534',8,11)],
 'cargo': [('1145',4,8),('1147',4,7),('1147',9,12)],
 'heavy': [('1443',8,12),('1443',34,38),('1443',49,52)],
 'niva': [('0291',.12,.90),('0291',1.2,2.5),('0291',3.0,4.5)],
 'lada2107': [('0966',8,12),('0966',17,21),('0966',31,35)],
 'lada2106': [('0290',.10,.75),('0290',.85,1.65),('0290',1.65,2.5)],
}

def decode(source):
 raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(SOURCE/(source+'.wav')),'-ar',str(RATE),'-ac','1','-f','f32le','-'])
 return np.frombuffer(raw,dtype='<f4').copy()

def write(name,sound,loop):
 sound=sound-sound.mean()
 if loop:
  n=min(int(RATE*.09),len(sound)//5)
  phase=np.linspace(0,1,n)
  k=.5-.5*np.cos(np.pi*phase)
  out=sound[n:].copy()
  out[-n:]=out[-n:]*(1-k)+sound[:n]*k
 else:
  out=sound.copy();n=min(int(RATE*.015),len(out)//4)
  out[:n]*=np.linspace(0,1,n);out[-n:]*=np.linspace(1,0,n)
 rms=np.sqrt(np.mean(out*out));out*=min(.18/max(rms,1e-9),.85/max(float(np.abs(out).max()),1e-9))
 data=(out*32767).astype('<i2').tobytes()
 with wave.open(str(DEST/(name+'.wav')),'wb')as f:
  f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(data)
 return {'file':name+'.wav','seconds':round(len(out)/RATE,4),'sha256':hashlib.sha256((DEST/(name+'.wav')).read_bytes()).hexdigest(),'loop':loop}

def main():
 DEST.mkdir(parents=True,exist_ok=True)
 decoded={i:decode(i)for i in SOURCES}
 manifest={'notice':'All vehicle recordings are disclosed substitutes, not authentic recordings of the represented game vehicles. Layer RPM anchors are estimates for playback. Idle/rev/load can be designed from steady recordings; no measured multi-RPM/load capture is claimed.','sources':{},'files':[]}
 for i,(slug,identity,author) in SOURCES.items():
  manifest['sources'][i]={'url':f'https://bigsoundbank.com/{slug}-s{i}.html','download':f'https://bigsoundbank.com/UPLOAD/bwf-en/{i}.wav','identity':identity,'author':author,'license':'CC0','sha256':hashlib.sha256((SOURCE/(i+'.wav')).read_bytes()).hexdigest()}
 for vehicle,cuts in CUTS.items():
  for layer,(i,start,end)in zip(['idle','rev','load'],cuts):
   record=write(vehicle+'_'+layer,decoded[i][int(start*RATE):int(end*RATE)],True)
   record.update(vehicle=vehicle,layer=layer,source=i,cut=[start,end]);manifest['files'].append(record)
 for name,i,start,end,loop in [('gravel_roll','1284',2,17,True),('mud_foley','0495',.2,9.2,True),('starter_petrol','0966',2.0,3.5,False),('starter_v8','0534',0,1.5,False),('stop_petrol','0966',47,49,False),('stop_v8','0534',22,24.5,False)]:
  record=write(name,decoded[i][int(start*RATE):int(end*RATE)],loop);record.update(source=i,cut=[start,end]);manifest['files'].append(record)
 (DEST/'SOURCES.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print('Prepared',len(manifest['files']),'recorded samples; peak-safe mono 44.1kHz, circular crossfades.')

if __name__=='__main__':main()
