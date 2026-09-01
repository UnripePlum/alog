// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Alog",
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
            name: "Alog",
            dependencies: ["MonitorKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
