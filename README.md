# TinyPreview

TinyPreview 是一个面向 Finder 的 macOS Quick Look 增强工具。选中文件或文件夹并按空格，即可通过系统快速预览窗口查看内容。

## 功能

- **文件夹预览**：以只读清单展示目录内容，不递归展开隐藏目录或包内容。
- **压缩包预览**：无需解压即可展示 ZIP、TAR、GZIP、BZIP2、XZ、7Z 和 RAR 等压缩包的内容清单。
- **纯文本预览**：按内容识别 UTF-8，以及带 BOM 的 UTF-16/UTF-32 文本，不依赖文件扩展名进行内容分类。
- **代码高亮**：根据标准扩展名、知名文件名或 shebang 识别常见编程语言并提供语法高亮。
- **Markdown 渲染**：将标题、强调、行内代码、列表、引用和链接渲染为可选择的富文本。
- **图片预览**：支持 Image I/O 能够解码的图片格式以及经过安全校验的 SVG。
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

Quick Look 会先根据系统识别出的内容类型选择扩展。未知扩展名产生的动态 UTI 不一定会被系统路由到 TinyPreview；TinyPreview 不会修改文件类型，也不会拦截 Finder 键盘事件。

## 项目结构

```text
TinyPreview/
├── App/        # 设置宿主应用
├── Core/       # 内容分类、加载和安全预算
├── QuickLook/  # Quick Look Preview Extension UI
└── Support/    # Extension Info.plist 和 entitlements
Tests/          # TinyPreviewCore 单元测试
```

## 已知限制

- 压缩包和文件夹只展示清单，不能在预览窗口内继续打开子项目。
- 不支持密码输入、加密压缩包或分卷压缩包解析。
- 无法可靠识别语言的文本会按普通纯文本展示，不进行猜测式高亮。
- macOS 将 `.ts` 同时用于 MPEG-2 Transport Stream；TinyPreview 为支持 TypeScript 而声明该系统类型，实际 MPEG-2 TS 视频可能因此由 TinyPreview 判定为非文本内容。
- 超过用户配置上限或内部安全预算的项目会显示明确的拒绝原因。
