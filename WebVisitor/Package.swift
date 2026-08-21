// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "WebVisitor",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        .target(
            name: "MonitorKit",
            resources: [.process("Resources/identity.json")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MonitorKitTests",
            dependencies: ["MonitorKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "WebVisitor",
            dependencies: ["MonitorKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
