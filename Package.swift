// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TinyPreviewCore",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "TinyPreviewCore", targets: ["TinyPreviewCore"])
    ],
    targets: [
        .target(
            name: "TinyPreviewCore",
            path: "TinyPreview/Core",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ImageIO"),
                .linkedFramework("UniformTypeIdentifiers"),
                .linkedLibrary("archive")
            ]
        ),
        .testTarget(name: "TinyPreviewCoreTests", dependencies: ["TinyPreviewCore"])
    ]
)
