<p align="center">
  <img src="icon.png" width="128" height="128" alt="TinyPreview icon">
</p>

<h1 align="center">TinyPreview</h1>

<p align="center">
  <a href="README.md">简体中文</a> · <strong>English</strong>
</p>

TinyPreview is a macOS Quick Look preview extension for Finder. Select a file or folder and press Space to see folder listings, archive contents, highlighted source code, formatted JSON/plist, and rendered Markdown in the system Quick Look window.

All previews are read-only: TinyPreview never extracts or edits files and never loads remote content.

## Features

### Folders and Archives

- **Folders**: Show a hierarchical listing directly. Each directory can be expanded or collapsed on its own, and the context menu copies names or relative paths. Hidden directories and package contents are not scanned recursively.
- **Archives**: List the contents of ZIP, TAR, GZIP, BZIP2, XZ, 7Z, and RAR archives without extracting them.

### Text and Source Code

- **Content-based text detection**: UTF-8 and BOM-marked UTF-16/UTF-32 text is previewed regardless of extension, including files without an extension and dotfiles such as `.gitignore` and `.gitattributes`.
- **Syntax highlighting**: Languages are recognized from the extension, well-known filenames, or the shebang:
  - Swift, Objective-C, C/C++, Rust, Go, Python, Ruby, Java, Kotlin, JavaScript, TypeScript, Lua, PHP, Dart, Scala, Zig
  - HTML, CSS, XML, SQL, Shell, JSON, YAML, TOML, INI/config files, Protobuf, GraphQL
  - `Dockerfile`, `Makefile`, `CMakeLists.txt`, shell configuration such as `.bashrc`/`.zshrc`, and `.env`/`.editorconfig`/`.npmrc`/`.gitconfig`
  - Text whose language cannot be identified reliably is shown as plain text, without guessed highlighting.
- **JSON / plist**: JSON is formatted automatically while keeping numbers exactly as written. XML and binary plists are shown as read-only XML. When parsing fails, the original text or a clear error is shown.
- **Markdown**: Headings, emphasis, inline code, lists, blockquotes, links, and tables are rendered as selectable rich text, with highlighting for code blocks in recognized languages.
- **Large-text excerpts**: When a file exceeds its size limit, choose “仅预览开头” (Preview beginning) to read at most 1 MB with a clear truncation notice. Limits are never raised automatically.

### Images

- Supports formats Image I/O can decode, plus SVG files that pass safety checks.
- The canvas supports pinch-to-zoom and panning. Double-click switches between fit-to-window and actual pixels, and small images are never enlarged. Transparent areas show a checkerboard.
- Large images whose decoded bitmap would exceed the memory budget are downsampled with a “已缩小显示” (Downsampled) notice; 100% zoom still corresponds to the original size.
- If all frames of an animation exceed the budget, only the first frame is shown, with a notice.

> Common image formats (PNG, JPEG, GIF, HEIC, and others) are usually handled by the built-in macOS preview. See “Which Files TinyPreview Previews” below.

### Unsupported Content

Unrecognized binaries and other unsupported content are handed back to macOS, which shows its default file information preview instead of a TinyPreview “unsupported” page.

## Which Files TinyPreview Previews

macOS displays some common types with Quick Look's built-in viewers and does not invoke any preview extension for them, even when TinyPreview declares the type. Tested through Finder on macOS 27.0.1:

| Previewed by TinyPreview | Handled by the built-in preview |
| --- | --- |
| Folders and archives such as ZIP and TAR.GZ | `.txt`, CSV, RTF, HTML |
| Source code (including Lua, PHP, Dart, Scala, Zig, Protobuf, GraphQL, CMake) | PNG, JPEG, GIF, HEIC, TIFF, SVG |
| `Dockerfile`, `Makefile`, INI, `.properties` | PDF, audio |
| JSON, plist, XML, YAML, Markdown | Files ending in `.txt` such as `CMakeLists.txt`, `.conf` |
| BMP, text and images without an extension | Extensions the system does not recognize (such as `.dat`) |

To check whether a preview comes from TinyPreview, keep the preview window open and run `pgrep -fl TinyPreviewQuickLook`; any output means TinyPreview is in use. The first preview of a newly created file, or right after the preview service restarts, is occasionally handled by the system; pressing Space again fixes it.

## Install and Use

1. Download and extract the ZIP from [GitHub Releases](https://github.com/lingmacker/TinyPreview/releases/latest) and move TinyPreview into Applications, or run `make install` from source.
2. Launch TinyPreview once so macOS registers the preview extension, and adjust preview size limits if needed.
3. Select a file or folder in Finder and press Space.

Release builds are ad hoc signed and are not Developer ID signed or notarized, so macOS may ask you to confirm the first launch in System Settings → Privacy & Security.

If previews do not appear, make sure TinyPreview is enabled in System Settings → General → Login Items & Extensions → Quick Look.

## Settings and Safety Budgets

**Preview size limits**: The TinyPreview app sets separate limits for text, source code, images, and archives. Files over their limit are not read, and the reason is shown. JSON and plist use the source code limit; folders are not size-limited. New settings take effect from the next preview.

| Category | Default | Range |
| --- | --- | --- |
| Plain text | 5 MB | 1–50 MB |
| Source code | 2 MB | 1–20 MB |
| Images | 100 MB | 1–500 MB |
| Archives | 200 MB | 1–2048 MB |

Settings are stored in the app's own preferences domain, `com.lingmacker.TinyPreview`, which the extension reads read-only. Settings that earlier versions wrote to the global domain are migrated and removed the first time the new app launches.

**Safety budgets** cannot be turned off and keep oversized or malformed files from blocking Quick Look:

- Folder and archive listings stop at 5,000 entries.
- Each preview gets at most 2 seconds; scanning, formatting, and syntax highlighting stop early when time runs out.
- Decoding uses at most 256 MB of memory.

## Known Limitations

- Types handled by the built-in preview (see the table above) cannot be routed to TinyPreview.
- Archives and folders show listings only; items inside them cannot be opened from the preview. Encrypted and multi-volume archives are not supported.
- The extension is sandboxed and can read only the previewed file, so Markdown images referenced by relative paths are not shown.
- “Preview beginning” applies only to text and source code, not to archives, images, or plists.
- macOS uses `.ts` for both TypeScript and MPEG-2 Transport Stream. TinyPreview declares that type to support TypeScript; actual TS video is classified as unsupported and handed back to the system preview.
- iCloud files that have not been downloaded are not downloaded automatically; a notice is shown instead.

## Build

Requires macOS 26 or later, an Apple Silicon Mac, and Xcode with the macOS 26 SDK. TinyPreview uses only the modern Quick Look Preview Extension and has no legacy `qlgenerator`.

```sh
make          # Build an ad hoc-signed Debug app
make run      # Build and launch
make install  # Build and install to /Applications/TinyPreview.app, replacing the old version
make clean    # Remove the .build directory
```

The built app is at `.build/xcode/Build/Products/Debug/TinyPreview.app`. To build Release or a specific version:

```sh
make build CONFIGURATION=Release
make build MARKETING_VERSION=1.2.3 CURRENT_PROJECT_VERSION=42
```

## Tests

```sh
make test     # Run core parser and loader regression tests through Xcode
make test-ui  # Local AppKit/SwiftUI interaction checks; requires a graphical session
```

The interaction checks cover text display, automatic Markdown/JSON handling, the image canvas, zooming, and the checkerboard background, and save regular, compact, and dark-mode captures to `.build/preview-checks/`. They do not replace checking in Finder that the extension is actually invoked. The test that reads and writes real user settings is skipped unless `TINYPREVIEW_TEST_GLOBAL_SETTINGS=1` is set.

## Releases

Pushing a `v<major>.<minor>.<patch>` tag triggers `.github/workflows/release.yml`, which builds an Apple Silicon Release app with Xcode 27 and uploads a ZIP archive and SHA-256 checksum file to the corresponding GitHub Release.

```sh
git tag v1.0.0
git push origin v1.0.0
```

## Project Structure

```text
TinyPreview/
├── App/        # Settings app
├── Core/       # Content classification, loading, syntax highlighting, and safety budgets
├── QuickLook/  # Quick Look preview extension UI
└── Support/    # Extension Info.plist and entitlements
Tests/          # Core regression tests and local interaction checks
```
