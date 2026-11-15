// 下载 three.js r128 / occt-import-js / three-dxf 离线资源到 WebAssets
import { writeFile, mkdir } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const outDir = resolve(here, '..', 'CadSee', 'Resources', 'WebAssets');

const targets = [
  {
    out: 'js/three.min.js',
    urls: [
      'https://cdn.jsdelivr.net/npm/three@0.128.0/build/three.min.js',
      'https://unpkg.com/three@0.128.0/build/three.min.js',
    ],
  },
  {
    out: 'js/OrbitControls.js',
    urls: ['https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js'],
  },
  {
    out: 'js/loaders/STLLoader.js',
    urls: ['https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/STLLoader.js'],
  },
  {
    out: 'js/loaders/OBJLoader.js',
    urls: ['https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/OBJLoader.js'],
  },
  {
    out: 'js/loaders/PLYLoader.js',
    urls: ['https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/PLYLoader.js'],
  },
  {
    out: 'js/loaders/GLTFLoader.js',
    urls: ['https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/GLTFLoader.js'],
  },
  {
    out: 'js/loaders/3MFLoader.js',
    urls: ['https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/3MFLoader.js'],
  },
  {
    out: 'js/dxf-viewer.min.js',
    urls: [
      'https://unpkg.com/three-dxf/dist/dxf-viewer.min.js',
      'https://cdn.jsdelivr.net/npm/three-dxf/dist/dxf-viewer.min.js',
      'https://unpkg.com/three-dxf/dist/dxf-viewer.js',
    ],
  },
  {
    out: 'js/occt/occt-import-js.js',
    urls: [
      'https://cdn.jsdelivr.net/gh/kovacsv/occt-import-js/dist/occt-import-js.js',
      'https://raw.githubusercontent.com/kovacsv/occt-import-js/master/dist/occt-import-js.js',
      'https://cdn.jsdelivr.net/gh/kovacsv/occt-import-js@master/dist/occt-import-js.js',
    ],
  },
  {
    out: 'js/occt/occt-import-js.wasm',
    urls: [
      'https://cdn.jsdelivr.net/gh/kovacsv/occt-import-js/dist/occt-import-js.wasm',
      'https://raw.githubusercontent.com/kovacsv/occt-import-js/master/dist/occt-import-js.wasm',
      'https://cdn.jsdelivr.net/gh/kovacsv/occt-import-js@master/dist/occt-import-js.wasm',
    ],
  },
];

async function fetchOne(url, timeoutMs = 60000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const resp = await fetch(url, { signal: controller.signal });
    if (!resp.ok) return { url, ok: false, status: resp.status };
    const buf = Buffer.from(await resp.arrayBuffer());
    return { url, ok: true, status: resp.status, bytes: buf.length };
  } catch (e) {
    return { url, ok: false, error: String(e && e.message || e) };
  } finally {
    clearTimeout(timer);
  }
}

for (const target of targets) {
  const dest = join(outDir, target.out);
  await mkdir(dirname(dest), { recursive: true });
  let saved = null;
  for (const url of target.urls) {
    const probe = await fetchOne(url);
    if (probe.ok) {
      const resp = await fetch(url);
      const buf = Buffer.from(await resp.arrayBuffer());
      await writeFile(dest, buf);
      saved = { url, bytes: buf.length };
      break;
    }
    console.log('  miss:', probe.url, probe.status || probe.error || '');
  }
  if (saved) {
    console.log('OK  ', target.out, `${(saved.bytes / 1024).toFixed(1)} KB`, '<-', saved.url);
  } else {
    console.log('FAIL', target.out);
  }
}
console.log('done');
