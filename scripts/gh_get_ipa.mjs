/* 轮询 GitHub Actions 构建并下载 IPA 产物。
 * 用法：node scripts/gh_get_ipa.mjs <PAT> <owner> <repo> [超时秒=1800]
 */
import { writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
const token = process.argv[2];
const owner = process.argv[3];
const repo = process.argv[4];
const timeoutSec = Number(process.argv[5] || 1800);
if (!token || !owner || !repo) {
  console.error('usage: node gh_get_ipa.mjs <PAT> <owner> <repo> [timeoutSec]');
  process.exit(2);
}

const API = 'https://api.github.com';
const headers = {
  Authorization: `Bearer ${token}`,
  'User-Agent': 'cadsee-fetcher',
  Accept: 'application/vnd.github+json',
  'X-GitHub-Api-Version': '2022-11-28'
};

async function api(method, path) {
  const resp = await fetch(API + path, { method, headers });
  const text = await resp.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* ignore */ }
  if (!resp.ok) throw new Error(`${method} ${path} -> ${resp.status}: ${text.slice(0, 300)}`);
  return json;
}

const sleep = (ms) => new Promise(r => setTimeout(r, ms));
const started = Date.now();

// 1. 找最新一次 workflow run
let run = null;
for (;;) {
  const data = await api('GET', `/repos/${owner}/${repo}/actions/runs?per_page=5`);
  const runs = (data.workflow_runs || []).filter(r => r.name === 'Build IPA');
  if (runs.length > 0) { run = runs[0]; break; }
  if (Date.now() - started > timeoutSec * 1000) throw new Error('超时：未找到 workflow run');
  console.log('等待 workflow run 出现…');
  await sleep(10000);
}
console.log('workflow run:', run.id, run.status, run.conclusion || '(进行中)');

// 2. 轮询至完成
while (run.status !== 'completed') {
  await sleep(20000);
  run = await api('GET', `/repos/${owner}/${repo}/actions/runs/${run.id}`);
  const secs = Math.round((Date.now() - started) / 1000);
  console.log(`[${secs}s] status=${run.status}`, run.conclusion ? `conclusion=${run.conclusion}` : '');
  if (Date.now() - started > timeoutSec * 1000) throw new Error('超时：构建未完成');
}
console.log('构建结论:', run.conclusion);
if (run.conclusion !== 'success') {
  throw new Error(`构建失败（${run.conclusion}），请查看 https://github.com/${owner}/${repo}/actions/runs/${run.id}`);
}

// 3. 下载 IPA artifact
const arts = await api('GET', `/repos/${owner}/${repo}/actions/runs/${run.id}/artifacts`);
const ipa = (arts.artifacts || []).find(a => a.name === 'CadSee-unsigned-ipa');
if (!ipa) throw new Error('未找到 CadSee-unsigned-ipa 产物');
console.log('产物:', ipa.name, (ipa.size_in_bytes / 1024 / 1024).toFixed(1), 'MB');

const outDir = join(root, 'dist');
mkdirSync(outDir, { recursive: true });
const zipPath = join(outDir, 'CadSee-unsigned-ipa.zip');
const resp = await fetch(ipa.archive_download_url, { headers });
if (!resp.ok) throw new Error('下载 artifact 失败: ' + resp.status);
writeFileSync(zipPath, Buffer.from(await resp.arrayBuffer()));
console.log('已下载:', zipPath);
