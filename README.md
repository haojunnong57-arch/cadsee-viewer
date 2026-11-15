# CadSee — iPhone 3D/CAD 看图软件

专为 iPhone（含 **iPhone Air / iOS 26**）打造的离线 CAD/3D 看图应用：
原生 SwiftUI 界面 + SceneKit 原生渲染 + 基于 **OpenCASCADE (OCCT)** 的 WebAssembly
CAD 引擎，把 CAD 能力完整搬到手机上。

> 设计参考成熟项目 Open Cascade **CAD Assistant**（App Store 官方 CAD 查看器，STEP/IGES/BREP
> 原生支持）的功能路线；本应用采用更轻量的技术栈实现同等核心能力，
> 并保持苹果设计美学与原生交互。

## 功能

- **3D / CAD 查看**
  - three.js Web 渲染：STL、OBJ、PLY、glTF / GLB、3MF
  - OCCT-WASM 引擎（CAD 精度解析）：**STEP / STP、IGES / IGS、BREP**
  - 原生 SceneKit：USDZ、DAE、SCN
  - 实体 / 线框切换、深色 / 浅色背景、等轴测 / 正面 / 俯视、透视 / 正交、自动取景、网格参考面
- **平面文件**：DXF 图纸（图层渲染）、PDF、SVG、常见图片（PNG/JPG/HEIC/WEBP/GIF/TIFF/BMP，双指缩放）
- **文件管理**：从「文件」App 导入、多选导入、搜索、重命名、删除、共享、最近打开、格式分组
- **苹果设计美学**：SF Symbols、毛玻璃控制条、深色模式、层级清晰（文件库 → 查看器 → 详情）

## 技术架构

| 层 | 实现 |
|---|---|
| UI | SwiftUI（iOS 17+，NavigationStack + 分层导航） |
| 原生 3D | SceneKit（USDZ / DAE / SCN） |
| CAD 引擎 | occt-import-js（OCCT → WASM，STEP/IGES/BREP） |
| Web 渲染 | three.js r128（STL/OBJ/PLY/glTF/3MF，离线下发，WKWebView + 自定义 URL Scheme，无网络请求） |
| DXF | three-dxf（图层/线型渲染） |
| 2D | PDFKit / WebKit / UIKit |

模型文件与 HTML/JS/WASM 资源全部在 App 沙盒内通过自定义 `cadsee://` scheme 离线加载，
**完全不需要联网**。

## 目录结构

```
project.yml                     # XcodeGen 工程定义
CadSee/
  App/                          # 入口
  Models/                       # 文件模型与图库存储
  Views/                        # 首页 / 列表 / 设置 / 许可
  Viewers/                      # SceneKit / Web / PDF / 图片查看器
  Support/                      # Web 资源管理、URL Scheme 处理器
  Resources/Assets.xcassets/    # App 图标与主题色
  Resources/WebAssets/          # three.js、occt-import-js、three-dxf 与 viewer.js
.github/workflows/build-ipa.yml # GitHub Actions 云编译
codemagic.yaml                  # Codemagic 云编译
scripts/gen_icon.py             # 图标生成脚本（Pillow）
```

## 云端编译（任选其一）

### 方案 A：GitHub Actions（推荐，公开仓库免费且不限时长）

1. 把本仓库推送到 GitHub **公开**仓库；
2. Push 到 `main` 后自动开始编译，或手动在 Actions 页 Run workflow；
3. 编译完成后在 **Artifacts** 下载 `CadSee-unsigned-ipa.zip`，解压得到 `CadSee-unsigned.ipa`。

### 方案 B：Codemagic（个人账户每月 500 分钟免费）

1. 在 [codemagic.io](https://codemagic.io) 用 GitHub 登录并连接仓库（选择 codemagic.yaml 模式）；
2. 触发 `build-ipa` 工作流；
3. 完成后从构建产物下载 `CadSee-unsigned.ipa`。

### 本地 macOS 编译

```bash
brew install xcodegen
xcodegen generate
xcodebuild build -project CadSee.xcodeproj -scheme CadSee \
  -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
mkdir -p Payload
cp -R DerivedData/Build/Products/Release-iphoneos/CadSee.app Payload/
zip -qry CadSee-unsigned.ipa Payload
```

## 安装到 iPhone（无需付费开发者账号）

未签名 IPA 需要用你自己的 Apple ID 在电脑上签名安装（完全免费）：

1. 电脑（Windows 7+ 或 macOS 10.12+）安装 **Sideloadly**（https://sideloadly.io）或 **AltStore + AltServer**（https://altstore.io）；
2. iPhone 用数据线连接电脑，并在手机上开启 **开发者模式**
   （设置 → 隐私与安全性 → 开发者模式）；
3. 把 `CadSee-unsigned.ipa` 拖入 Sideloadly，输入你的 Apple ID（免费账号即可），开始安装；
4. 安装后在 设置 → 通用 → VPN 与设备管理 中信任你的证书即可打开。

> 免费 Apple ID 的限制：签名 **7 天有效**（到期前重新连电脑刷一次即可）、
> 同时最多 **3 个**自签应用。有付费开发者账号（$99/年）则有效期 1 年、无数量限制。

## 许可

本应用代码采用 MIT 许可。内嵌开源组件：

- three.js — MIT
- occt-import-js（OpenCASCADE 的 Emscripten 移植）— LGPL-2.1
- three-dxf — MIT

详见应用内「设置 → 开源许可」。
