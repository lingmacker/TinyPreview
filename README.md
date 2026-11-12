<p align="center">
  <img src="icon.png" width="128" height="128" alt="TinyPreview 图标">
</p>

<h1 align="center">TinyPreview</h1>

<p align="center">
  <strong>简体中文</strong> · <a href="README.en.md">English</a>
</p>

TinyPreview 是一个面向 Finder 的 macOS Quick Look 预览扩展。选中文件或文件夹按空格，即可在系统快速预览窗口中查看文件夹清单、压缩包内容、高亮源代码、格式化 JSON/plist 和渲染后的 Markdown。

所有预览都是只读的：不解压、不编辑文件，也不加载远程内容。

## 功能

### 文件夹与压缩包

- **文件夹**：直接展示层级清单，每个目录可单独展开/折叠，右键可复制名称或相对路径。不递归扫描隐藏目录和包内容。
- **压缩包**：无需解压即可列出 ZIP、TAR、GZIP、BZIP2、XZ、7Z 和 RAR 的内容。

### 文本与源代码

- **按内容识别文本**：UTF-8 以及带 BOM 的 UTF-16/UTF-32 文本都能预览，不依赖扩展名；无扩展名文件和 `.gitignore`、`.gitattributes` 等点文件同样适用。
- **语法高亮**：根据扩展名、知名文件名或 shebang 识别语言：
  - Swift、Objective-C、C/C++、Rust、Go、Python、Ruby、Java、Kotlin、JavaScript、TypeScript、Lua、PHP、Dart、Scala、Zig
  - HTML、CSS、XML、SQL、Shell、JSON、YAML、TOML、INI/配置文件、Protobuf、GraphQL
  - `Dockerfile`、`Makefile`、`CMakeLists.txt`、`.bashrc`/`.zshrc` 等 Shell 配置、`.env`/`.editorconfig`/`.npmrc`/`.gitconfig`
  - 无法可靠识别语言的文本按普通纯文本展示，不做猜测式高亮。
- **JSON / plist**：JSON 自动格式化并保留数字的原始写法；XML 和二进制 plist 以只读 XML 展示。解析失败时显示原文或明确的错误。
- **Markdown**：标题、强调、行内代码、列表、引用、链接和表格渲染为可选择的富文本，已识别语言的代码块会高亮。
- **大文本片段预览**：超过大小上限时可选择“仅预览开头”，最多读取 1 MB 并明确标记截断，不会自动调高上限。

### 图片

- 支持 Image I/O 可解码的格式，以及通过安全校验的 SVG。
- 画布支持捏合缩放和拖动；双击在“适应窗口”和“原始像素”之间切换；小图不会被放大。透明区域显示棋盘格。
- 解码后会超过内存预算的大图按比例缩小显示，并提示“已缩小显示”；100% 缩放仍对应原图尺寸。
- 动画图片的全部帧超出预算时只显示首帧，并给出提示。

> 常见图片格式（PNG、JPEG、GIF、HEIC 等）通常由 macOS 内置预览接管，见下文“哪些文件会由 TinyPreview 预览”。

### 不支持的内容

无法识别的二进制等内容会交还给 macOS，显示系统默认的文件信息预览，而不是显示 TinyPreview 的“不支持”页面。

## 哪些文件会由 TinyPreview 预览

macOS 会用 Quick Look 内置查看器直接显示部分常见类型，此时不会调用任何预览扩展，即使 TinyPreview 声明了该类型。以下为 macOS 27.0.1 上通过 Finder 的实测结果：

| 由 TinyPreview 预览 | 由系统内置预览接管 |
| --- | --- |
| 文件夹、ZIP、TAR.GZ 等压缩包 | `.txt`、CSV、RTF、HTML |
| 源代码（含 Lua、PHP、Dart、Scala、Zig、Protobuf、GraphQL、CMake） | PNG、JPEG、GIF、HEIC、TIFF、SVG |
| `Dockerfile`、`Makefile`、INI、`.properties` | PDF、音频 |
| JSON、plist、XML、YAML、Markdown | `CMakeLists.txt` 等 `.txt` 结尾的文件、`.conf` |
| BMP、无扩展名的文本和图片 | 系统不认识的扩展名（如 `.dat`） |

判断某次预览是否由 TinyPreview 提供：保持预览窗口打开，运行 `pgrep -fl TinyPreviewQuickLook`，有输出即为 TinyPreview。新建的文件或刚重启预览服务后，第一次预览偶尔会由系统接管，再按一次空格即可。

## 安装与使用

1. 从 [GitHub Releases](https://github.com/lingmacker/TinyPreview/releases/latest) 下载 DMG，将 TinyPreview 拖入“应用程序”文件夹；或从源码执行 `make install`。
2. 启动一次 TinyPreview，让系统注册预览扩展，并按需调整预览大小上限。
3. 在 Finder 中选中文件或文件夹，按空格。

发布版使用 Ad Hoc 签名，未经过 Developer ID 签名和公证，首次打开时可能需要在“系统设置 → 隐私与安全性”中确认。

如果预览没有生效，确认“系统设置 → 通用 → 登录项与扩展 → 快速查看”中 TinyPreview 已启用。

## 设置与安全预算

**预览大小上限**：在 TinyPreview App 中可分别设置文本、源代码、图片和压缩包的上限，超过上限的文件不读取内容，并显示原因。JSON/plist 沿用源代码上限，文件夹不受上限限制。新设置从下一次预览开始生效。

| 分类 | 默认 | 可调范围 |
| --- | --- | --- |
| 纯文本 | 5 MB | 1–50 MB |
| 源代码 | 2 MB | 1–20 MB |
| 图片 | 100 MB | 1–500 MB |
| 压缩包 | 200 MB | 1–2048 MB |

设置保存在 App 自己的偏好域 `com.lingmacker.TinyPreview`，扩展只读访问。旧版本写入全局偏好域的设置会在首次启动新版 App 时自动迁移并清除。

**安全预算**：不可关闭，防止超大或异常文件卡住 Quick Look。

- 文件夹和压缩包最多列出 5,000 项。
- 单次处理最多 2 秒；扫描、格式化和语法高亮超时会提前停止。
- 解码内存最多 256 MB。

## 已知限制

- 系统内置预览接管的类型（见上表）无法改由 TinyPreview 预览。
- 压缩包和文件夹只展示清单，不能在预览窗口中继续打开子项目；不支持加密压缩包和分卷压缩包。
- 扩展运行在沙盒中，只能读取被预览的文件，Markdown 中通过相对路径引用的图片不会显示。
- “仅预览开头”只适用于文本和源代码，不适用于压缩包、图片和 plist。
- macOS 将 `.ts` 同时用于 TypeScript 和 MPEG-2 Transport Stream；TinyPreview 为支持 TypeScript 声明了该类型，真正的 TS 视频会被判定为不支持，并交还系统预览。
- iCloud 中尚未下载的文件不会触发下载，只显示提示。

## 构建

需要 macOS 26 或更高版本、Apple Silicon Mac，以及支持 macOS 26 SDK 的 Xcode。TinyPreview 只使用现代 Quick Look Preview Extension，不包含旧式 `qlgenerator`。

```sh
make          # 构建 Ad Hoc 签名的 Debug App
make run      # 构建并启动
make install  # 构建并安装到 /Applications/TinyPreview.app，替换旧版本
make clean    # 删除 .build 目录
```

构建产物位于 `.build/xcode/Build/Products/Debug/TinyPreview.app`。构建 Release 或指定版本：

```sh
make build CONFIGURATION=Release
make build MARKETING_VERSION=1.2.3 CURRENT_PROJECT_VERSION=42
```

## 测试

```sh
make test     # 通过 Xcode 运行核心解析与加载回归测试
make test-ui  # 本地 AppKit/SwiftUI 交互检查，需要图形会话
```

交互检查覆盖正文展示、Markdown/JSON 自动处理、图片画布、缩放和棋盘格背景，并将普通、紧凑和深色模式的截图输出到 `.build/preview-checks/`。它们不能代替在 Finder 中验证扩展是否被调用。读写真实用户设置的测试默认跳过，设置 `TINYPREVIEW_TEST_GLOBAL_SETTINGS=1` 才会运行。

## 发布

推送 `v<主版本>.<次版本>.<修订版本>` 标签会触发 `.github/workflows/release.yml`，使用 Xcode 27 构建 Apple Silicon Release App，并将 DMG 和 SHA-256 校验文件上传到对应的 GitHub Release。

```sh
git tag v1.0.0
git push origin v1.0.0
```

## 项目结构

```text
TinyPreview/
├── App/        # 设置 App
├── Core/       # 内容分类、加载、语法高亮和安全预算
├── QuickLook/  # Quick Look 预览扩展界面
└── Support/    # 扩展的 Info.plist 和 entitlements
Tests/          # 核心回归测试与本地交互检查
```
