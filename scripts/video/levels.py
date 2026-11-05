"""Per-frame talk levels for the two characters from a mono mix and the speaker split.

Speaker A (星川さん) drives the left character, B (秀竹) the right one. The level is
the same RMS the page computes from its analysers, over a ~43 ms window, scaled per
speaker so their loud syllables (90th percentile) sit at 0.3, well over the 0.12 threshold.
usage: levels.py audio.mp3 diarized.json out.json [fps]
"""
import json, subprocess, sys
import numpy as np

SR = 48000
audio, diar, out = sys.argv[1:4]
fps = int(sys.argv[4]) if len(sys.argv) > 4 else 30
y = np.frombuffer(subprocess.run(['ffmpeg', '-v', 'error', '-i', audio, '-ac', '1', '-ar', str(SR), '-f', 'f32le', '-'],
                                 capture_output=True, check=True).stdout, dtype=np.float32)
segs = json.load(open(diar))['segments']
duration = len(y) / SR
n = int(duration * fps)
win = 2048
who = np.full(n, -1)
for s in segs:   # a little slack: transcript edges run a bit tight
    who[max(0, int((s['start'] - 0.15) * fps)):min(n, int((s['end'] + 0.15) * fps) + 1)] = 'AB'.index(s['speaker'])
rms = np.zeros(n)
for i in range(n):
    c = int(i / fps * SR)
    a = y[max(0, c - win // 2):c + win // 2]
    rms[i] = float(np.sqrt(np.mean(a * a))) if len(a) else 0.0
gain = [0.3 / max(1e-6, np.percentile(rms[who == k], 90)) for k in (0, 1)]
frames = []
for i in range(n):
    pair = [0.0, 0.0]
    if who[i] >= 0:
        pair[who[i]] = round(min(1.0, rms[i] * gain[who[i]]), 3)
    frames.append(pair)
json.dump({'fps': fps, 'duration': duration, 'frames': frames}, open(out, 'w'))
print(f'{n} frames, {duration:.1f}s')
