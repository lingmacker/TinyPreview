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
make run           # 构建并启动 TinyPreview
make install       # 构建并安装到 /Applications
make test          # 运行 Swift Package 测试
make clean         # 删除 Xcode 构建产物
make open-project  # 使用 Xcode 打开工程
make print-app     # 输出 App 构建路径
make help          # 显示完整命令说明
```

构建指定版本：

```sh
make build MARKETING_VERSION=1.2.3 CURRENT_PROJECT_VERSION=42
```

使用 Developer ID 签名 Release 构建：

```sh
make build \
  CONFIGURATION=Release \
  CODE_SIGN_IDENTITY="Developer ID Application: Example" \
  DEVELOPMENT_TEAM=TEAMID
```

可通过 `INSTALL_DIR` 修改安装目录：

```sh
make install INSTALL_DIR="$HOME/Applications"
```

## 使用

1. 执行 `make install` 安装 TinyPreview。
2. 启动 `/Applications/TinyPreview.app`，配置各类文件的预览大小上限。
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
