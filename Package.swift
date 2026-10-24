// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SLTemplateEditor",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "SLTemplateEditor", targets: ["SLTemplateEditor"]),
        .library(name: "SLTemplateKit", targets: ["SLTemplateKit"]),
    ],
    targets: [
        .target(name: "SLTemplateKit"),
        .executableTarget(
            name: "SLTemplateEditor",
            dependencies: ["SLTemplateKit"],
            linkerSettings: [.linkedFramework("CoreMIDI")]
        ),
        .testTarget(name: "SLTemplateKitTests", dependencies: ["SLTemplateKit"]),
    ],
    swiftLanguageVersions: [.v5]
)
