// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TinyPreviewCore",
    platforms: [.macOS("26.0")],
    products: [.library(name: "TinyPreviewCore", targets: ["TinyPreviewCore"])],
    targets: [
        .target(name: "TinyPreviewCore", path: "TinyPreview/Core", linkerSettings: [.linkedLibrary("archive")]),
        .testTarget(name: "TinyPreviewCoreTests", dependencies: ["TinyPreviewCore"], path: "Tests/TinyPreviewCoreTests")
    ],
    swiftLanguageModes: [.v5]
)
