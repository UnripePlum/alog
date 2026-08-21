// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SiteMonitor",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        // 엔진 코어: GUI/WebKit 비의존 순수 로직 (유닛 테스트 대상)
        .target(
            name: "MonitorKit",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MonitorKitTests",
            dependencies: ["MonitorKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // SwiftUI 앱 + WebPage(WebKit) 체커
        .executableTarget(
            name: "SiteMonitor",
            dependencies: ["MonitorKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
