<p align="center">
  <img src="icon.png" width="128" height="128" alt="TinyPreview 图标">
</p>

<h1 align="center">TinyPreview</h1>

<p align="center">
  <strong>简体中文</strong> · <a href="README.en.md">English</a>
</p>

TinyPreview 是一个面向 Finder 的 macOS Quick Look 增强工具。选中文件或文件夹并按空格，即可通过系统快速预览窗口查看内容。

## 功能

- **文件夹预览**：直接展示只读层级清单，支持逐个目录展开/折叠，以及复制名称和相对路径；不附加顶部摘要或工具栏，不递归扫描隐藏目录或包内容。
- **压缩包预览**：无需解压即可展示 ZIP、TAR、GZIP、BZIP2、XZ、7Z 和 RAR 等压缩包的内容清单。
- **纯文本预览**：按内容识别 UTF-8，以及带 BOM 的 UTF-16/UTF-32 文本，不依赖文件扩展名进行内容分类；支持 `.gitignore`、`.gitattributes`、`.gitmodules`、`.env`、`.editorconfig`、`.npmrc`、`.bashrc`、`.zshrc` 等常见点文件。
- **代码高亮**：根据标准扩展名、知名文件名或 shebang 识别常见编程语言并提供语法高亮。
- **JSON / plist**：JSON 自动格式化并保留数字原始写法；XML 和二进制 plist 以只读 XML 展示。解析失败时回退可解码的原文，或显示明确错误。
- **CSV / TSV 表格**：支持带引号的分隔符、转义引号和字段内换行，以只读表格展示并可复制单元格；首行保留为普通记录。
- **大文本片段预览**：文本或源代码超过大小/读取上限时，可主动选择“仅预览开头”，最多读取 1 MB 片段，并明确标记截断；不会自动提高上限。
- **Markdown 渲染**：默认直接将标题、强调、行内代码、列表、引用、链接和表格渲染为可选择的富文本，支持已识别语言的代码块高亮。
- **图片预览**：以下自定义界面仅在系统实际调用 TinyPreview 扩展时生效。支持 Image I/O 能够解码的图片格式以及经过安全校验的 SVG；支持缩放、拖动，格式、尺寸、文件大小和透明通道信息显示在右下角浮层；透明区域默认使用棋盘格，无顶部信息栏和背景切换控件。
- **分类大小限制**：可分别配置文本、源代码、图片和压缩包的预览大小上限。
- **安全预算**：限制扫描条目数、处理时间和内存使用，避免超大文件或异常压缩包阻塞 Quick Look。

## 系统要求

- macOS 26 或更高版本
- Apple Silicon Mac
- 构建时需要支持 macOS 26 SDK 的 Xcode 和 Command Line Tools

TinyPreview 仅使用现代 Quick Look Preview Extension，不包含旧式 `qlgenerator` fallback。

## 构建

默认构建 ad-hoc 签名的 Debug App：

```sh
make
```

构建产物位于：

```text
.build/xcode/Build/Products/Debug/TinyPreview.app
```

其他常用命令：

```sh
make run    # 构建并启动 TinyPreview
make clean  # 删除 .build 构建目录
```

构建指定版本：

```sh
make build MARKETING_VERSION=1.2.3 CURRENT_PROJECT_VERSION=42
```

构建 Ad Hoc 签名的 Release App：

```sh
make build CONFIGURATION=Release
```

## 测试

```sh
make test     # 核心解析与加载回归测试
make test-ui  # 本地 AppKit/SwiftUI 交互检查，需可用的 macOS 图形会话
```

交互检查覆盖无工具栏的正文展示、Markdown/JSON 自动处理、单元格复制按键、图片右下角信息浮层、缩放和默认棋盘格透明背景，并将普通、紧凑及深色预览截图输出至 `.build/preview-checks/`。这些检查不替代 Finder 中的扩展路由测试。为避免改动实际设置，会写入用户全局偏好的旧测试默认跳过。

## 发布

推送 `v<主版本>.<次版本>.<修订版本>` 标签会触发 `.github/workflows/release.yml`。工作流使用 Xcode 27 构建 Apple Silicon Release App，并上传 DMG 与 SHA-256 校验文件到对应的 GitHub Release。

```sh
git tag v1.0.0
git push origin v1.0.0
```

自动发布的 App 使用 Ad Hoc 签名，未经过 Developer ID 签名和公证；首次打开时 macOS 可能要求用户在系统安全设置中确认。

最新版本可从 [GitHub Releases](https://github.com/lingmacker/TinyPreview/releases/latest) 下载 DMG。打开 DMG 后，将 TinyPreview 拖入 Applications 文件夹。

## 使用

1. 从 DMG 安装 TinyPreview，或使用 `make run` 直接启动构建产物。
2. 启动 TinyPreview，配置各类文件的预览大小上限。
3. 在 Finder 中选择受支持的项目并按空格。

预览窗口中的常用操作：

文本预览直接展示正文，不附加重复的文件标题或文本操作工具栏；系统 Quick Look 标题栏保持不变。

- 点击内容清单中每个目录前的箭头展开/折叠；右键复制名称或相对路径。
- 在表格中点击单元格后按 `⌘C`，或右键复制单元格。
- 图片信息浮于预览区域右下角，不拦截缩放或拖动；双击图片切换适应窗口和原始尺寸。

CSV/TSV 沿用纯文本大小上限，JSON/plist 沿用源代码大小上限。所有操作均为只读，不执行表格公式，不解压或编辑文件，也不自动加载远程内容。

Quick Look 会先根据系统识别出的内容类型选择扩展。TinyPreview 声明通用 `public.data` 类型，以接收系统识别为通用数据的无扩展名点文件；这也可能接管其他通用数据文件的预览，非文本且不受支持的内容会显示“不支持”。未知扩展名产生的动态 UTI（例如 `.env.local`）仍不保证会被系统路由到 TinyPreview；TinyPreview 不会修改文件类型，也不会拦截 Finder 键盘事件。

## 项目结构

```text
TinyPreview/
├── App/        # 设置宿主应用
├── Core/       # 内容分类、加载和安全预算
├── QuickLook/  # Quick Look Preview Extension UI
└── Support/    # Extension Info.plist 和 entitlements
Tests/          # 核心回归测试与本地预览交互检查
```

## 已知限制

- macOS 内置图片预览可能优先接管 PNG/JPEG；右下角信息浮层和默认棋盘格仅在 TinyPreview 扩展实际被调用时生效。
- 压缩包和文件夹只展示清单，不能在预览窗口内继续打开子项目。
- 不支持密码输入、加密压缩包或分卷压缩包解析。
- 无法可靠识别语言的文本会按普通纯文本展示，不进行猜测式高亮。
- macOS 将 `.ts` 同时用于 MPEG-2 Transport Stream；TinyPreview 为支持 TypeScript 而声明该系统类型，实际 MPEG-2 TS 视频可能因此由 TinyPreview 判定为非文本内容。
- CSV/TSV 最多显示 1,000 条记录、100 列和 5,000 个单元格；达到记录/单元格上限时显示完整记录片段，超过列数或单元格内容预算时回退原文。
- 超过用户配置上限或内部安全预算的项目会显示明确的拒绝原因；“仅预览开头”只适用于文本/代码，不适用于压缩包、图片、CSV/TSV 或 plist。
