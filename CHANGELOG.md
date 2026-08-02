# 更新记录

## 1.0.2 - 2026-08-02

自 1.0.0 以来的修改：

### 改进

- 源代码关键字、类型、字符串、数字和注释改用 Dracula 配色，同时保留 macOS 默认文本与行号栏背景。（`f92068d`）
- 代码预览加载期间使用一致的高亮前景色，并让行号颜色与语法主题协调。（`f92068d`）
- 关闭 TinyPreview 配置窗口后自动退出 App，避免无窗口进程继续驻留。（`a182333`）

### 修复

- 修复单行注释可能错误覆盖后续代码的问题，确保注释后的关键字、类型、字符串和数字继续正确高亮。（`f92068d`）

## 1.0.0 - 2026-08-02

### 首次发布

- 支持 Finder 文件夹及 ZIP、TAR、GZIP、BZIP2、XZ、7Z、RAR 压缩包内容清单预览。
- 支持按内容识别 Unicode 纯文本，并为常见源代码提供语法高亮。
- 支持 Markdown 富文本渲染及常见图片格式预览。
- 提供按内容类别配置的预览大小限制和固定安全预算。
- 提供 macOS 27 Icon Composer 应用图标及自动 GitHub Release 工作流。

[1.0.2]: https://github.com/lingmacker/TinyPreview/compare/v1.0.0...v1.0.2
[1.0.0]: https://github.com/lingmacker/TinyPreview/releases/tag/v1.0.0
