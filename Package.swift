// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WisprAssist",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "WisprAssist", targets: ["WisprAssist"])
    ],
    targets: [
        // Pure, UI-free logic (geometry + editability rules). Fully unit-testable.
        .target(name: "WisprAssistCore"),
        .executableTarget(name: "WisprAssist", dependencies: ["WisprAssistCore"]),
        .testTarget(name: "WisprAssistCoreTests", dependencies: ["WisprAssistCore"])
    ]
)
