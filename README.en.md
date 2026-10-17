<p align="center">
  <img src="icon.png" width="128" height="128" alt="TinyPreview icon">
</p>

<h1 align="center">TinyPreview</h1>

<p align="center">
  <a href="README.md">简体中文</a> · <strong>English</strong>
</p>

TinyPreview is a macOS Quick Look enhancement for Finder. Select a file or folder and press Space to view its contents in the system Quick Look window.

## Features

- **Folder previews**: Display a read-only hierarchical list directly, with per-directory expand/collapse arrows and name/relative-path copying. No summary or toolbar is added above the list. Hidden directories and packages are not recursively scanned.
- **Archive previews**: List the contents of ZIP, TAR, GZIP, BZIP2, XZ, 7Z, and RAR archives without extracting them.
- **Plain text previews**: Identify UTF-8 and BOM-marked UTF-16/UTF-32 text by content rather than file extension. Supports common dotfiles such as `.gitignore`, `.gitattributes`, `.gitmodules`, `.env`, `.editorconfig`, `.npmrc`, `.bashrc`, and `.zshrc`.
- **Syntax highlighting**: Recognize common programming languages using standard extensions, well-known filenames, or shebangs.
- **JSON / plist**: JSON is formatted automatically while preserving numeric tokens. XML and binary plists are displayed as read-only XML. Parsing failures fall back to decodable raw text or show an explicit error.
- **CSV / TSV tables**: Display read-only tables with quoted delimiters, escaped quotes, embedded newlines, and cell copying. The first row remains an ordinary record.
- **Large-text excerpts**: When text or source code exceeds a size/read limit, explicitly choose “仅预览开头” (Preview beginning) to read an excerpt of at most 1 MB with a clear truncation notice. Limits are never raised automatically.
- **Markdown rendering**: Automatically render headings, emphasis, inline code, lists, blockquotes, links, and tables as selectable rich text, with syntax highlighting for recognized fenced-code languages.
- **Image previews**: The custom interface applies only when macOS actually invokes the TinyPreview extension. Support image formats that Image I/O can decode, as well as SVG files that pass safety checks. Includes zooming, panning, and a bottom-right overlay for format, dimensions, file size, and alpha-channel information. Transparent areas use a checkerboard by default, with no top information bar or background controls.
- **Per-category size limits**: Configure separate preview size limits for text, source code, images, and archives.
- **Safety budgets**: Limit scanned entries, processing time, and memory usage to prevent oversized files or malformed archives from blocking Quick Look.

## Requirements

- macOS 26 or later
- Apple Silicon Mac
- Xcode and Command Line Tools with macOS 26 SDK support to build the app

TinyPreview uses only the modern Quick Look Preview Extension and does not include a legacy `qlgenerator` fallback.

## Build

Build an ad hoc-signed Debug app by default:

```sh
make
```

The built app is located at:

```text
.build/xcode/Build/Products/Debug/TinyPreview.app
```

Other useful commands:

```sh
make run    # Build and launch TinyPreview
make clean  # Remove the .build directory
```

Build a specific version:

```sh
make build MARKETING_VERSION=1.2.3 CURRENT_PROJECT_VERSION=42
```

Build an ad hoc-signed Release app:

```sh
make build CONFIGURATION=Release
```

## Tests

```sh
make test     # Core parser and loader regression tests
make test-ui  # Local AppKit/SwiftUI interaction checks; requires a macOS graphical session
```

Interaction checks cover toolbar-free text content, automatic Markdown/JSON processing, the cell-copy shortcut, bottom-right image information overlays, zooming, and the default checkerboard transparency background. Regular, compact, and dark preview captures are saved to `.build/preview-checks/`. These checks do not replace Finder extension-routing tests. The legacy test that writes global user preferences is skipped by default to avoid changing actual settings.

## Releases

Pushing a `v<major>.<minor>.<patch>` tag triggers `.github/workflows/release.yml`. The workflow uses Xcode 27 to build an Apple Silicon Release app and uploads a DMG and SHA-256 checksum file to the corresponding GitHub Release.

```sh
git tag v1.0.0
git push origin v1.0.0
```

Automatically published apps are ad hoc-signed, not Developer ID-signed or notarized. On first launch, macOS may require confirmation in the system security settings.

Download the latest DMG from [GitHub Releases](https://github.com/lingmacker/TinyPreview/releases/latest). Open the DMG and drag TinyPreview into the Applications folder.

## Usage

1. Install TinyPreview from the DMG, or run `make run` to launch the built app directly.
2. Launch TinyPreview and configure preview size limits for each file category.
3. Select a supported item in Finder and press Space.

Common actions in the preview window:

Text previews show content directly, without a duplicate filename heading or text toolbar. The system Quick Look title bar is unchanged.

- Use each directory's arrow to expand/collapse its entries. Right-click to copy names or relative paths.
- Click a table cell and press `⌘C`, or right-click to copy the cell.
- Image information floats at the bottom-right of the preview without intercepting zooming or panning. Double-click an image to switch between fit-to-window and original size.

CSV/TSV use the plain-text size limit; JSON/plist use the source-code size limit. All actions are read-only: formulas are not evaluated, files are not extracted or edited, and remote content is not loaded automatically.

Quick Look first selects an extension based on the content type identified by the system. TinyPreview declares the generic `public.data` type to receive extensionless dotfiles that the system identifies as generic data. This may also cause it to handle previews for other generic data files; unsupported non-text content displays an “Unsupported” message. Dynamic UTIs generated for unknown extensions, such as `.env.local`, are still not guaranteed to be routed to TinyPreview. TinyPreview does not change file types or intercept Finder keyboard events.

## Project Structure

```text
TinyPreview/
├── App/        # Settings host app
├── Core/       # Content classification, loading, and safety budgets
├── QuickLook/  # Quick Look Preview Extension UI
└── Support/    # Extension Info.plist and entitlements
Tests/          # Core regression tests and local preview interaction checks
```

## Known Limitations

- macOS may route PNG/JPEG files to its built-in image preview. The bottom-right information overlay and default checkerboard apply only when the TinyPreview extension is actually invoked.
- Archive and folder previews only display lists; child items cannot be opened within the preview window.
- Password input, encrypted archives, and split archives are not supported.
- Text whose language cannot be reliably identified is displayed as plain text, without speculative syntax highlighting.
- macOS also uses `.ts` for MPEG-2 Transport Stream files. TinyPreview declares that system type to support TypeScript, so actual MPEG-2 TS videos may be classified as non-text content by TinyPreview.
- CSV/TSV display at most 1,000 records, 100 columns, and 5,000 cells. Record/cell limits produce a clearly marked excerpt of complete records; excessive columns or cell content fall back to raw text.
- Items exceeding configured size limits or internal safety budgets display an explicit reason for rejection. Preview-beginning excerpts apply only to text/source code, not archives, images, CSV/TSV, or plists.
