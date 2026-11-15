"""下载便携版 git（MinGit）到 tools/ 目录。"""
import json
import os
import urllib.request
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.normpath(os.path.join(HERE, "..", "tools"))
os.makedirs(TOOLS, exist_ok=True)

api = "https://api.github.com/repos/git-for-windows/git/releases/latest"
req = urllib.request.Request(api, headers={"User-Agent": "cadsee-fetch", "Accept": "application/vnd.github+json"})
with urllib.request.urlopen(req, timeout=60) as resp:
    release = json.load(resp)

asset = None
for a in release.get("assets", []):
    name = a["name"]
    if name.startswith("MinGit-") and name.endswith("-64-bit.zip"):
        asset = a
        break
if asset is None:
    raise SystemExit("未找到 MinGit 资产")

url = asset["browser_download_url"]
print("下载:", asset["name"], round(asset["size"] / 1024 / 1024, 1), "MB")
zip_path = os.path.join(TOOLS, "mingit.zip")
urllib.request.urlretrieve(url, zip_path)

with zipfile.ZipFile(zip_path) as zf:
    zf.extractall(TOOLS)
os.remove(zip_path)
print("解压完成 ->", TOOLS)
