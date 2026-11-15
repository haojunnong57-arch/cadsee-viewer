/* 使用 GitHub API + 便携 git 发布仓库并触发 Actions 编译。
 * 用法：node scripts/gh_publish.mjs <PAT>
 * 流程：/user 查用户名 → 创建公开仓库 cadsee-viewer → 用 tools/MiniGit 推送 → 输出仓库地址
 */
import { execFileSync } from 'node:child_process';
import { existsSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
const token = process.argv[2];
if (!token) {
  console.error('usage: node gh_publish.mjs <PAT>');
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
  if (!resp.ok) {
    throw new Error(`${method} ${path} -> ${resp.status}: ${text.slice(0, 300)}`);
  }
  return json;
}

// 1. 用户信息
const user = await api('GET', '/user');
const login = user.login;
console.log('GitHub 账号:', login, '(', user.name || 'no name', ')');

// 2. 仓库（已存在则复用）
const repoName = 'cadsee-viewer';
let repo;
try {
  repo = await api('GET', `/repos/${login}/${repoName}`);
  console.log('仓库已存在，复用:', repo.full_name);
} catch {
  repo = await api('POST', '/user/repos', {
    name: repoName,
    description: 'CadSee — iPhone 3D/CAD 看图软件（STL/OBJ/PLY/STEP/IGES/BREP/glTF/3MF/DXF/PDF/SVG）',
    homepage: '',
    public: true,
    auto_init: false,
    default_branch: 'main'
  });
  console.log('已创建仓库:', repo.full_name);
}

// 3. 找 git（tools/MiniGit 或系统 git）
function findGit() {
  const candidates = [];
  const tools = join(root, 'tools');
  try {
    for (const d of readdirSync(tools)) {
      const g = join(tools, d, 'cmd', 'git.exe');
      if (existsSync(g)) candidates.push(g);
    }
  } catch { /* ignore */ }
  candidates.push('git');
  return candidates;
}

const gitBin = findGit().find(g => {
  try { execFileSync(g, ['--version'], { stdio: 'ignore' }); return true; } catch { return false; }
});
if (!gitBin) {
  console.error('找不到 git，请先下载 MiniGit 到 tools/ 目录');
  process.exit(3);
}
console.log('使用 git:', gitBin);

function git(args, opts = {}) {
  execFileSync(gitBin, args, { cwd: root, stdio: 'inherit', ...opts });
}

// 4. 提交并推送
const remote = `https://x-access-token:${token}@github.com/${login}/${repoName}.git`;
try { git(['remote', 'remove', 'origin']); } catch { /* ignore */ }
git(['remote', 'add', 'origin', remote]);
git(['branch', '-M', 'main']);
git(['add', '-A']);
try {
  git(['commit', '-m', 'CadSee iOS 看图应用：SwiftUI + SceneKit + occt-import-js(OCCT WASM) + three.js + three-dxf']);
} catch (e) {
  console.log('（无改动需要提交）');
}
git(['push', '-u', 'origin', 'main', '--force']);

console.log('\n推送完成: https://github.com/' + login + '/' + repoName);
console.log('Actions 将自动开始编译：https://github.com/' + login + '/' + repoName + '/actions');
