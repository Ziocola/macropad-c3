// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacropadConfig",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "MacropadConfig", path: "Sources/MacropadConfig")
    ]
)
