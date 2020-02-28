// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "symbolicate",

    platforms: [
        .macOS("10.10")
    ],

    products: [
        .executable(name: "symbolicate", targets: ["symbolicate"])
    ],

    dependencies: [
        .package(url: "https://github.com/kylef/Commander", from: "0.9.0")
    ],

    targets: [
        .target(name: "symbolicate", dependencies: ["Commander"])
    ],

    swiftLanguageVersions: [.version("4"), .version("4.2"), .version("5")]
)

