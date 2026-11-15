/* 通过 GitHub Contents API 发布仓库（无需本地 git），并触发 Actions 编译。
 * 用法：node scripts/gh_publish_api.mjs <PAT>
 */
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join, resolve, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
const token = process.argv[2];
if (!token) {
  console.error('usage: node gh_publish_api.mjs <PAT>');
  process.exit(2);
}

const API = 'https://api.github.com';
const headers = {
  Authorization: `Bearer ${token}`,
  'User-Agent': 'cadsee-publisher',
  Accept: 'application/vnd.github+json',
  'X-GitHub-Api-Version': '2022-11-28'
};

async function api(method, path, body) {
  const resp = await fetch(API + path, {
    method,
    headers: { ...headers, ...(body ? { 'Content-Type': 'application/json' } : {}) },
    body: body ? JSON.stringify(body) : undefined
  });
  const text = await resp.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* ignore */ }
  if (!resp.ok) throw new Error(`${method} ${path} -> ${resp.status}: ${text.slice(0, 400)}`);
  return json;
}

const sleep = (ms) => new Promise(r => setTimeout(r, ms));

// 1. 用户信息
const user = await api('GET', '/user');
const login = user.login;
console.log('GitHub 账号:', login);

// 2. 仓库
const repoName = 'cadsee-viewer';
let repo;
try {
  repo = await api('GET', `/repos/${login}/${repoName}`);
  console.log('仓库已存在，复用:', repo.full_name);
} catch {
  repo = await api('POST', '/user/repos', {
    name: repoName,
    description: 'CadSee — iPhone 3D/CAD 看图软件（STL/OBJ/PLY/STEP/IGES/BREP/glTF/3MF/DXF/PDF/SVG）',
    public: true,
    auto_init: false,
    default_branch: 'main'
  });
  console.log('已创建仓库:', repo.full_name);
}

// 3. 收集待上传文件
const excludeDirs = new Set(['.git', 'tools', 'dist', 'DerivedData', 'Payload']);
const excludeSuffix = ['.ipa', '.zip', 'asset-version.txt'];
function walk(dir, list) {
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    if (excludeDirs.has(name)) continue;
    const st = statSync(full);
    if (st.isDirectory()) { walk(full, list); continue; }
    if (excludeSuffix.some(s => name.endsWith(s))) continue;
    list.push(full);
  }
  return list;
}
const files = walk(root, []);
const relFiles = files.map(f => relative(root, f).replace(/\\/g, '/')).sort();
console.log(`待上传 ${relFiles.length} 个文件`);
for (const f of relFiles) console.log('  ', f, f.endsWith('.wasm') ? '(wasm)' : '');

// 4. 逐个上传（串行，避免并发冲突）
let uploaded = 0;
for (const relPath of relFiles) {
  const full = join(root, relPath);
  const content = readFileSync(full).toString('base64');
  await api('PUT', `/repos/${login}/${repoName}/contents/${encodeURI(relPath)}`, {
    message: `add ${relPath}`,
    content
  });
  uploaded++;
  console.log(`[${uploaded}/${relFiles.length}] ${relPath}`);
  await sleep(150);
}

// 5. 触发 workflow_dispatch
await sleep(2000);
try {
  await api('POST', `/repos/${login}/${repoName}/actions/workflows/build-ipa.yml/dispatches`, {
    ref: 'main'
  });
  console.log('已触发 build-ipa.yml 编译');
} catch (e) {
  console.log('dispatch 失败（可能 push 事件已自动触发）:', e.message.slice(0, 200));
}

console.log('\n仓库: https://github.com/' + login + '/' + repoName);
console.log('Actions: https://github.com/' + login + '/' + repoName + '/actions');
