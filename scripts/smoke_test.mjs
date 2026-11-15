/* CadSee Web 管线冒烟测试（Node.js）
 * 验证：three.js r128 各 Loader 解析、occt-import-js WASM 解析 STEP、
 * dxf-parser 解析 DXF、viewer.js 语法。
 */
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Buffer } from 'node:buffer';

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const W = resolve(here, '..', 'CadSee', 'Resources', 'WebAssets');

let pass = 0;
let fail = 0;
function ok(name, cond, detail = '') {
  if (cond) { pass++; console.log('PASS', name, detail); }
  else { fail++; console.log('FAIL', name, detail); }
}

// ---------- 1. three.js 核心 ----------
const THREE = require(join(W, 'js/three.min.js'));
global.THREE = THREE;
ok('three.js require', !!THREE.WebGLRenderer && !!THREE.BufferGeometry);

require(join(W, 'js/loaders/STLLoader.js'));
require(join(W, 'js/loaders/OBJLoader.js'));
require(join(W, 'js/loaders/PLYLoader.js'));
require(join(W, 'js/loaders/GLTFLoader.js'));
require(join(W, 'js/loaders/3MFLoader.js'));
ok('loaders attach', !!THREE.STLLoader && !!THREE.OBJLoader && !!THREE.PLYLoader && !!THREE.GLTFLoader && !!THREE.ThreeMFLoader);

// 立方体数据
const V = [
  [-1, -1, -1], [1, -1, -1], [1, 1, -1], [-1, 1, -1],
  [-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]
];
// 12 个三角形
const TRIS = [
  [0, 1, 2], [0, 2, 3], [4, 6, 5], [4, 7, 6],
  [0, 4, 5], [0, 5, 1], [1, 5, 6], [1, 6, 2],
  [2, 6, 7], [2, 7, 3], [3, 7, 4], [3, 4, 0]
];

// ---------- 2. STL ASCII ----------
function asciiStl() {
  const parts = ['solid cube'];
  for (const f of TRIS) {
    const [a, b, c] = f.map(i => V[i]);
    parts.push('facet normal 0 0 1');
    parts.push('outer loop');
    parts.push(`vertex ${a.join(' ')}`);
    parts.push(`vertex ${b.join(' ')}`);
    parts.push(`vertex ${c.join(' ')}`);
    parts.push('endloop');
    parts.push('endfacet');
  }
  parts.push('endsolid cube');
  return parts.join('\n');
}
const stlGeo = new THREE.STLLoader().parse(asciiStl());
ok('STL ascii parse', stlGeo.attributes.position.count === 36, `verts=${stlGeo.attributes.position.count}`);

// ---------- 3. STL binary ----------
function binaryStl() {
  const tris = 12;
  const buf = Buffer.alloc(84 + tris * 50);
  buf.write('binary stl test', 0, 'ascii');
  buf.writeUInt32LE(tris, 80);
  let o = 84;
  for (const f of TRIS) {
    const [a, b, c] = f.map(i => V[i]);
    buf.writeFloatLE(0, o); buf.writeFloatLE(0, o + 4); buf.writeFloatLE(1, o + 8);
    let p = o + 12;
    for (const v of [a, b, c]) {
      buf.writeFloatLE(v[0], p); buf.writeFloatLE(v[1], p + 4); buf.writeFloatLE(v[2], p + 8);
      p += 12;
    }
    buf.writeUInt16LE(0, p);
    o += 50;
  }
  return buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength);
}
const stlBinGeo = new THREE.STLLoader().parse(binaryStl());
ok('STL binary parse', stlBinGeo.attributes.position.count === 36, `verts=${stlBinGeo.attributes.position.count}`);

// ---------- 4. OBJ ----------
function objText() {
  const lines = V.map(v => `v ${v.join(' ')}`);
  for (const f of TRIS) {
    lines.push(`f ${f[0] + 1} ${f[1] + 1} ${f[2] + 1}`);
  }
  return lines.join('\n');
}
const objGroup = new THREE.OBJLoader().parse(objText());
let objTris = 0;
objGroup.traverse(n => { if (n.isMesh) objTris += n.geometry.attributes.position.count / 3; });
ok('OBJ parse', objGroup.children.length > 0 && objTris === 12, `tris=${objTris}`);

// ---------- 5. PLY ----------
function plyText() {
  const lines = [
    'ply', 'format ascii 1.0', `element vertex ${V.length}`,
    'property float x', 'property float y', 'property float z',
    'element face 12', 'property list uchar int vertex_indices', 'end_header'
  ];
  for (const v of V) lines.push(v.join(' '));
  for (const f of TRIS) {
    lines.push(`3 ${f[0]} ${f[1]} ${f[2]}`);
  }
  return lines.join('\n') + '\n';
}
const plyGeo = new THREE.PLYLoader().parse(plyText());
ok('PLY parse', plyGeo.attributes && plyGeo.attributes.position.count === 8 && plyGeo.index.count === 36, `verts=${plyGeo.attributes && plyGeo.attributes.position.count}, index=${plyGeo.index && plyGeo.index.count}`);

// ---------- 6. GLB ----------
function makeGlb() {
  const pos = [];
  for (const f of TRIS) for (const i of f) pos.push(...V[i]);
  const bin = Buffer.from(Float32Array.from(pos).buffer);
  const json = {
    asset: { version: '2.0' },
    scene: 0,
    scenes: [{ nodes: [0] }],
    nodes: [{ mesh: 0 }],
    meshes: [{ primitives: [{ attributes: { POSITION: 0 } }] }],
    accessors: [{ bufferView: 0, componentType: 5126, count: 36, type: 'VEC3', min: [-1, -1, -1], max: [1, 1, 1] }],
    bufferViews: [{ buffer: 0, byteOffset: 0, byteLength: bin.length, target: 34962 }],
    buffers: [{ byteLength: bin.length }]
  };
  const jb = Buffer.from(JSON.stringify(json), 'utf8');
  const pad = (b, m) => Buffer.alloc((m - b.length % m) % m, 0x20);
  const jbp = Buffer.concat([jb, pad(jb, 4)]);
  const binp = Buffer.concat([bin, pad(bin, 4)]);
  const header = Buffer.alloc(12);
  header.writeUInt32LE(0x46546C67, 0);
  header.writeUInt32LE(2, 4);
  header.writeUInt32LE(12 + 8 + jbp.length + 8 + binp.length, 8);
  const cj = Buffer.alloc(8); cj.writeUInt32LE(jbp.length, 0); cj.writeUInt32LE(0x4E4F534A, 4);
  const cb = Buffer.alloc(8); cb.writeUInt32LE(binp.length, 0); cb.writeUInt32LE(0x004E4942, 4);
  return Buffer.concat([header, cj, jbp, cb, binp]);
}
await new Promise((resolvePromise) => {
  const glb = makeGlb();
  const glbAB = glb.buffer.slice(glb.byteOffset, glb.byteOffset + glb.byteLength);
  new THREE.GLTFLoader().parse(
    glbAB, '',
    (gltf) => {
      let tris = 0;
      gltf.scene.traverse(n => { if (n.isMesh) tris += n.geometry.attributes.position.count / 3; });
      ok('GLB parse', tris === 12, `tris=${tris}`);
      resolvePromise();
    },
    (err) => { ok('GLB parse', false, String(err)); resolvePromise(); }
  );
});

// ---------- 7. occt-import-js（真实 WASM 解析 STEP）----------
const factory = require(join(W, 'js/occt/occt-import-js.js'));
ok('occt factory', typeof factory === 'function');
const occt = await factory({ locateFile: (name) => join(W, 'js/occt', name) });
ok('occt init', !!occt && typeof occt.ReadStepFile === 'function', `has ReadIgesFile=${typeof occt.ReadIgesFile === 'function'}, ReadBrepFile=${typeof occt.ReadBrepFile === 'function'}`);
if (occt && typeof occt.ReadStepFile === 'function') {
  const stp = readFileSync(join(here, 'fixtures', 'cube.stp'));
  const result = occt.ReadStepFile(stp, null);
  ok('STEP parse success', !!result && result.success === true, result && result.error ? String(result.error) : '');
  const meshes = (result && result.meshes) || [];
  const triangles = meshes.reduce((sum, m) => sum + (m.index ? m.index.array.length / 3 : 0), 0);
  ok('STEP mesh data', meshes.length >= 1 && triangles > 0, `meshes=${meshes.length}, tris=${triangles}`);
  const m0 = meshes[0] || {};
  ok('STEP attributes shape', !!m0.attributes && !!m0.attributes.position && !!m0.index, m0.color ? `color=[${m0.color.map(c => c.toFixed(2)).join(',')}]` : 'no color');
}

// ---------- 7b. fflate（3MFLoader 依赖）----------
const fflate = require(join(W, 'js/fflate.min.js'));
ok('fflate load', typeof fflate.unzipSync === 'function' && typeof fflate.zipSync === 'function');
if (typeof fflate.zipSync === 'function' && typeof fflate.unzipSync === 'function') {
  try {
    const zip = fflate.zipSync({ 'model/3dmodel.model': new Uint8Array([1, 2, 3]) });
    const out = fflate.unzipSync(zip);
    ok('fflate roundtrip', out['model/3dmodel.model'] && out['model/3dmodel.model'].length === 3);
  } catch (e) {
    ok('fflate roundtrip', false, String(e));
  }
}

// ---------- 8. dxf-parser ----------
const dxfMod = require(join(W, 'js/dxf-parser.js'));
const DxfParser = dxfMod.DxfParser || dxfMod;
ok('dxf-parser load', typeof DxfParser === 'function');
if (typeof DxfParser === 'function') {
  const tinyDxf = [
    '0', 'SECTION', '2', 'ENTITIES', '0', 'LINE',
    '8', '0', '10', '0', '20', '0', '30', '0',
    '11', '10', '21', '10', '31', '0',
    '0', 'CIRCLE', '8', '0', '10', '5', '20', '5', '30', '0', '40', '3',
    '0', 'ENDSEC', '0', 'EOF'
  ].join('\n');
  try {
    const parsed = new DxfParser().parseSync(tinyDxf);
    ok('DXF parse', Array.isArray(parsed.entities) && parsed.entities.length === 2, `entities=${parsed.entities.length}`);
  } catch (e) {
    ok('DXF parse', false, String(e));
  }
}

// ---------- 9. viewer.js / index.html 引用完整性 ----------
const viewerJs = readFileSync(join(W, 'viewer.js'), 'utf8');
const indexHtml = readFileSync(join(W, 'index.html'), 'utf8');
for (const src of ['js/three.min.js', 'js/OrbitControls.js', 'js/loaders/STLLoader.js', 'js/loaders/OBJLoader.js',
  'js/loaders/PLYLoader.js', 'js/loaders/GLTFLoader.js', 'js/fflate.min.js', 'js/loaders/3MFLoader.js',
  'js/occt/occt-import-js.js', 'js/dxf-parser.js', 'js/dxf-viewer.min.js', 'viewer.js']) {
  ok(`index.html references ${src}`, indexHtml.includes(src));
}
ok('viewer.js mentions loadOcct/loadDxf', viewerJs.includes('loadOcct') && viewerJs.includes('loadDxf'));

console.log(`\n===== ${pass} passed, ${fail} failed =====`);
process.exit(fail === 0 ? 0 : 1);
