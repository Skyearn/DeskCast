# 文档桌映

`文档桌映` 是一个 macOS 菜单栏应用，可以把 macOS 可预览的文件投影到桌面指定区域，适合排班表、课表、值班表、参考资料、演讲提词或常驻文档展示。

![文档桌映演示](.github/readme-assets/deskcast-demo.gif)

## 功能特性

- 纯菜单栏应用，不占 Dock。
- 支持多个文档同时投影。
- 支持多屏幕选择，不同文档可投影到不同显示器。
- 支持自定义投影区域位置和大小。
- 支持内容缩放与透明程度调节。
- 自动保存每个投影项的参数，下次打开自动恢复。
- 支持 macOS 可预览的文件，实际预览能力由系统 `Quick Look` / `PDFKit` 决定。

## 支持范围

理论上只要是 macOS 当前机器可以直接预览的文件，都可以尝试添加到投影中，例如：

- PDF
- Microsoft Office 文档
- iWork 文档
- 纯文本、CSV、RTF
- 图片及其他可被系统预览的文件

说明：

- 目录本身不会被添加。
- 包类型文件如果系统支持预览，会按文件处理。
- 复杂动画、宏、交互式内容是否正常显示，取决于系统预览能力，而不是应用单独解析。

## 运行要求

- macOS 14.0 或更高版本
- Xcode 16 或更新版本用于本地编译

## 本地编译

先生成应用图标资源：

```bash
swift -module-cache-path '.build/SwiftModuleCache' 'Tools/GenerateAppIcon.swift'
```

然后编译应用：

```bash
xcodebuild \
  -project 'DeskCast.xcodeproj' \
  -scheme 'DeskCast' \
  -configuration Debug \
  -derivedDataPath '.build' \
  build \
  CODE_SIGNING_ALLOWED=NO
```

编译产物默认位于：

```text
.build/Build/Products/Debug/DeskCast.app
```

## GitHub Actions

仓库包含一个自动编译工作流：

- 文件位置：`.github/workflows/build.yml`
- 触发方式：`push`、`pull_request`、手动触发
- 产物内容：未签名的 `DeskCast.app` 压缩包

工作流会：

1. 在 macOS Runner 上生成最新图标资源
2. 以 `Release` 配置编译应用
3. 打包 `DeskCast.app`
4. 上传为 GitHub Actions Artifact

另外还包含一个发布工作流：

- 文件位置：`.github/workflows/release.yml`
- 触发方式：推送 `v*` 标签，或手动触发
- 产物内容：自动创建 GitHub Release，并上传 zip 附件

发布示例：

```bash
git tag v1.0.0
git push origin v1.0.0
```

## 发布前建议

- 确认应用名称、本地化文案和图标都已定稿
- 在真实多屏环境下再回归一次位置、透明度和缩放
- 如果要对外分发，建议后续补上代码签名与公证

## 项目结构

```text
DeskCast/
├── DeskCast.xcodeproj
├── DeskCast/
│   ├── DeskCastApp.swift
│   ├── ContentView.swift
│   ├── AppState.swift
│   ├── DesktopProjectionWindowController.swift
│   ├── ProjectionDocumentView.swift
│   └── Assets.xcassets
├── Tools/
│   ├── GenerateAppIcon.swift
│   └── GenerateMenuBarIconPreviews.swift
└── Design/
    └── IconPreviews/
```
