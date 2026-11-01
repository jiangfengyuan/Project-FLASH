// swift-tools-version: 6.0
import PackageDescription

// Developer-only Release harness; nothing is linked into the shipping apps.
let package = Package(name: "FlashBench", platforms: [.macOS(.v15)],
    dependencies: [.package(path: "../../shared/FlashKit")],
    targets: [.executableTarget(name: "FlashBench", dependencies: [
        .product(name: "FlashCore", package: "FlashKit")
    ])])
