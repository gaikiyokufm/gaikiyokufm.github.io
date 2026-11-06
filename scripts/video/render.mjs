// Render the pixel-art stage to an mp4: the page's own drawing code runs here under
// @napi-rs/canvas, one frame per tick, and the frames are piped into ffmpeg.
// usage: node render.mjs page.html levels.json audio.mp3 out.mp4 "title" [seconds]
import { readFileSync } from 'node:fs';
import { spawn } from 'node:child_process';
import { createCanvas, GlobalFonts, ImageData } from '@napi-rs/canvas';

const [page, levelsPath, audioPath, outPath, title = '', limit] = process.argv.slice(2);
GlobalFonts.registerFromPath(new URL('./fonts/DotGothic16-Regular.ttf', import.meta.url).pathname, 'DotGothic16');
const { fps, duration, frames } = JSON.parse(readFileSync(levelsPath, 'utf8'));
const W = 214 * 9, H = 120 * 9;   // 1926x1080, cropped to 1920 by ffmpeg
const stage = createCanvas(W, H);

const stub = () => new Proxy({ style: {}, dataset: {}, value: '0.12' }, {
  get: (o, k) => (k in o ? o[k] : () => stub()),
});
const RENDER = {};
const ctx = {
  window: { RENDER },
  document: {
    getElementById: id => (id === 'stage' ? stage : stub()),
    createElement: tag => (tag === 'canvas' ? createCanvas(1, 1) : stub()),
    querySelectorAll: () => [],
  },
  matchMedia: () => ({ matches: false }),
  localStorage: { getItem: () => null, setItem: () => {} },
  requestAnimationFrame: () => {},
  ImageData,
};
const html = readFileSync(page, 'utf8');
const code = html.slice(html.indexOf('<script>') + 8, html.lastIndexOf('</script>'));
new Function(...Object.keys(ctx), code)(...Object.values(ctx));

const total = Math.min(frames.length, limit ? Math.round(limit * fps) : Infinity);
RENDER.input = now => {
  const i = Math.min(frames.length - 1, Math.round(now / 1000 * fps));
  return { levels: frames[i], progress: now / 1000 / duration, chapter: title };
};

const ff = spawn('ffmpeg', ['-y', '-v', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', `${W}x${H}`, '-r', String(fps), '-i', '-',
  '-i', audioPath, '-map', '0:v', '-map', '1:a', '-map_chapters', '-1', '-map_metadata', '-1', '-t', String(total / fps), '-vf', 'crop=1920:1080:3:0', '-c:v', 'libx264', '-preset', 'veryfast', '-tune', 'animation',
  '-crf', '18', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '160k', '-movflags', '+faststart', outPath], { stdio: ['pipe', 'inherit', 'inherit'] });
const sc = stage.getContext('2d');
const started = Date.now();
for (let i = 0; i < total; i++) {
  RENDER.frame(i * 1000 / fps);
  const ok = ff.stdin.write(Buffer.from(sc.getImageData(0, 0, W, H).data.buffer));
  if (!ok) await new Promise(r => ff.stdin.once('drain', r));
  if (i % (fps * 60) === 0) process.stderr.write(`\r${Math.round(i / fps)}s / ${Math.round(total / fps)}s`);
}
ff.stdin.end();
await new Promise(r => ff.on('close', r));
process.stderr.write(`\ndone in ${((Date.now() - started) / 1000).toFixed(0)}s → ${outPath}\n`);
process.exit(0);   // skip native finalizers, which crash @napi-rs/canvas on exit under Node 24
