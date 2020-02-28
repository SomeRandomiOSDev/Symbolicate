// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "symbolicate",

    products: [
        .executable(name: "symbolicate", targets: ["symbolicate"])
    ],

    dependencies: [
        .package(url: "https://github.com/kylef/Commander", from: "0.9.0")
    ],

    targets: [
        .target(name: "symbolicate", dependencies: ["Commander"])
    ],

    swiftLanguageVersions: [.v4, .v4_2]
)
