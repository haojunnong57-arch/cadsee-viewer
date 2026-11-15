# 开发能力（Skills）清单与集成说明

> 按任务要求「先找适合开发的 skills 并装上」。结论：DeepSeek Harness 的官方插件目录
> （@deepseek-ai/* 全套 bundles）中没有 iOS/SwiftUI/CAD 开发类 skill，因此按照
> 「优先用 GitHub 找成熟项目」的要求，直接把业界成熟的开源组件作为本软件的
> 核心能力安装进了项目（`CadSee/Resources/WebAssets/`），并用子代理完成了
> 云端编译/签名/安装方案的调研。

## 已集成的成熟组件（即本项目的“开发技能”）

| 组件 | 来源 | 作用 | 许可 |
|---|---|---|---|
| three.js r128 | github.com/mrdoob/three.js | WebGL 渲染、STL/OBJ/PLY/glTF/3MF 解析、OrbitControls 交互 | MIT |
| occt-import-js | github.com/kovacsv/occt-import-js | OpenCASCADE (OCCT) 的 WASM 移植：**STEP/IGES/BREP CAD 几何解析**（与官方 CAD Assistant 同内核家族） | LGPL-2.1 |
| three-dxf | github.com/gdsestimating/three-dxf | DXF 二维图纸图层渲染（依赖 dxf-parser） | MIT |
| dxf-parser | github.com/gdsestimating/dxf-parser | DXF 文本解析 | MIT |
| fflate | github.com/101arrowz/fflate | 3MF 压缩包解压（3MFLoader 依赖） | MIT |
| SceneKit + ModelIO | Apple 系统框架 | 原生高性能 STL/OBJ/PLY/USDZ 渲染 | 系统内置 |
| PDFKit / WebKit / UIKit | Apple 系统框架 | PDF、SVG、图片查看 | 系统内置 |

## 参考的成熟项目

- **CAD Assistant**（Open Cascade 官方，App Store 在架）— 手机端 CAD 查看器的事实标准，
  支持 STEP/IGES/BREP/glTF/OBJ/PLY/STL。本项目功能对标其核心格式支持，
  但采用 SwiftUI + WASM 轻量方案替代其 Qt/OCCT 原生编译（后者需完整 Qt+OCCT 工具链）。

## 调研结论（已验证，2026-11）

- **编译**：GitHub Actions 公开仓库 macOS 免费且不限时长；`macos-26` runner 默认 Xcode 26.6。
  Codemagic 个人账户 500 分钟/月（mac_mini_m2）。
- **未签名 IPA**：`CODE_SIGNING_ALLOWED=NO` 三件套 + Payload 打包，产物可由
  Sideloadly / AltStore 用免费 Apple ID 重签（7 天有效、3 应用上限、需电脑）。
- **iPhone Air**：2025-09 发布，A19 Pro，出厂 iOS 26；本应用部署目标 iOS 17 可直接安装。
- **本地验证**：Node.js 冒烟测试（JS 语法 + 各 Loader 解析样例文件 + occt-import-js
  WASM 实际解析 STEP 测试件），见 `scripts/smoke_test.js`。
