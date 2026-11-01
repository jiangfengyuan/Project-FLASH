// swift-tools-version: 6.0
import PackageDescription

// Developer-only codec probe. No new third-party dependency or app target.
let package = Package(name: "FlashBackupProbe", platforms: [.macOS(.v15)],
    dependencies: [.package(path: "../../shared/FlashKit")],
    targets: [.executableTarget(name: "FlashBackupProbe", dependencies: [
        .product(name: "FlashCore", package: "FlashKit")
    ]), .executableTarget(name: "FlashPersistenceProbe", dependencies: [
        .product(name: "FlashCore", package: "FlashKit")
    ])])
