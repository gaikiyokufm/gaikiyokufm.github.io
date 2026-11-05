"""Split a two-person episode into speakers without any cloud AI.

Each transcript segment gets a voice fingerprint (MFCC mean/std plus median
pitch); the fingerprints are clustered into two groups.
usage: diarize.py audio.mp3 transcript.json out.json
"""
import json, subprocess, sys, types
_lzma = types.ModuleType('lzma')   # this Python lacks _lzma; nothing here compresses with it
class _Unavailable:
    def read(self): raise OSError('lzma unavailable')
    write = seek = tell = close = flush = read
_lzma.LZMAFile = _lzma.LZMACompressor = _lzma.LZMADecompressor = _Unavailable
_lzma.FORMAT_XZ = _lzma.FORMAT_ALONE = 0
sys.modules.setdefault('lzma', _lzma)
import numpy as np, librosa
from sklearn.preprocessing import StandardScaler
from sklearn.mixture import GaussianMixture

SR = 16000
audio, transcript, out = sys.argv[1:4]
y = np.frombuffer(subprocess.run(['ffmpeg', '-v', 'error', '-i', audio, '-ac', '1', '-ar', str(SR), '-f', 'f32le', '-'],
                                 capture_output=True, check=True).stdout, dtype=np.float32)
segs = json.load(open(transcript))['segments']

feats, pitch = [], []
for s in segs:
    a = y[int(s['start'] * SR):int(s['end'] * SR)]
    if len(a) < SR // 4:
        a = np.pad(a, (0, SR // 4 - len(a)))
    m = librosa.feature.mfcc(y=a, sr=SR, n_mfcc=20)[1:]          # drop c0 (loudness)
    rms = librosa.feature.rms(y=a)[0]
    voiced = rms > np.percentile(rms, 40)                         # ignore pauses
    m = m[:, voiced[:m.shape[1]]] if voiced.any() else m
    f0 = librosa.yin(a, fmin=60, fmax=400, sr=SR)
    f0 = f0[voiced[:len(f0)]] if voiced.any() else f0
    pitch.append(float(np.median(f0)))
    feats.append(np.concatenate([m.mean(1), m.std(1), [np.log(pitch[-1])] * 3]))

X = StandardScaler().fit_transform(np.array(feats))
gm = GaussianMixture(2, covariance_type='diag', n_init=10, random_state=0).fit(X)
lab = gm.predict(X)
conf = gm.predict_proba(X).max(1)
dur = np.array([s['end'] - s['start'] for s in segs])
med = [float(np.median([p for p, l in zip(pitch, lab) if l == k])) for k in (0, 1)]
share = [float(dur[lab == k].sum() / dur.sum()) for k in (0, 1)]
print('speaker A/B median pitch Hz:', [round(v) for v in med], ' talk share:', [round(v, 2) for v in share])
res = [{'start': round(s['start'], 2), 'end': round(s['end'], 2), 'speaker': 'AB'[l], 'conf': round(float(c), 2),
        'pitch': round(p), 'text': s['text']} for s, l, c, p in zip(segs, lab, conf, pitch)]
json.dump({'pitch': med, 'share': share, 'segments': res}, open(out, 'w'), ensure_ascii=False, indent=1)
