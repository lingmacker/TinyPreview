<p align="center">
  <img src="icon.png" width="128" height="128" alt="TinyPreview icon">
</p>

<h1 align="center">TinyPreview</h1>

<p align="center">
  <a href="README.md">简体中文</a> · <strong>English</strong>
</p>

TinyPreview is a macOS Quick Look enhancement for Finder. Select a file or folder and press Space to view its contents in the system Quick Look window.

## Features

- **Folder previews**: Display directory contents as a read-only list, without recursively expanding hidden directories or package contents.
- **Archive previews**: List the contents of ZIP, TAR, GZIP, BZIP2, XZ, 7Z, and RAR archives without extracting them.
- **Plain text previews**: Identify UTF-8 and BOM-marked UTF-16/UTF-32 text by content rather than file extension. Supports common dotfiles such as `.gitignore`, `.gitattributes`, `.gitmodules`, `.env`, `.editorconfig`, `.npmrc`, `.bashrc`, and `.zshrc`.
- **Syntax highlighting**: Recognize common programming languages using standard extensions, well-known filenames, or shebangs.
- **Markdown rendering**: Render headings, emphasis, inline code, lists, blockquotes, and links as selectable rich text.
- **Image previews**: Support image formats that Image I/O can decode, as well as SVG files that pass safety checks.
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

Quick Look first selects an extension based on the content type identified by the system. TinyPreview declares the generic `public.data` type to receive extensionless dotfiles that the system identifies as generic data. This may also cause it to handle previews for other generic data files; unsupported non-text content displays an “Unsupported” message. Dynamic UTIs generated for unknown extensions, such as `.env.local`, are still not guaranteed to be routed to TinyPreview. TinyPreview does not change file types or intercept Finder keyboard events.

## Project Structure

```text
TinyPreview/
├── App/        # Settings host app
├── Core/       # Content classification, loading, and safety budgets
├── QuickLook/  # Quick Look Preview Extension UI
└── Support/    # Extension Info.plist and entitlements
Tests/          # TinyPreviewCore unit tests
```

## Known Limitations

- Archive and folder previews only display lists; child items cannot be opened within the preview window.
- Password input, encrypted archives, and split archives are not supported.
- Text whose language cannot be reliably identified is displayed as plain text, without speculative syntax highlighting.
- macOS also uses `.ts` for MPEG-2 Transport Stream files. TinyPreview declares that system type to support TypeScript, so actual MPEG-2 TS videos may be classified as non-text content by TinyPreview.
- Items exceeding configured size limits or internal safety budgets display an explicit reason for rejection.
