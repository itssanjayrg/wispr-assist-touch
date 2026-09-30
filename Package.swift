// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AssistTouch",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "AssistTouch", targets: ["AssistTouch"])
    ],
    targets: [
        // Pure, UI-free logic (geometry + editability rules). Fully unit-testable.
        .target(name: "AssistTouchCore"),
        .executableTarget(name: "AssistTouch", dependencies: ["AssistTouchCore"]),
        .testTarget(name: "AssistTouchCoreTests", dependencies: ["AssistTouchCore"])
    ]
)
