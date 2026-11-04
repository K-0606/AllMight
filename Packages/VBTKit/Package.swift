// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VBTKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "VBTCore", targets: ["VBTCore"]),
        .library(name: "VBTVision", targets: ["VBTVision"]),
    ],
    targets: [
        // 純計算，只依賴 Foundation / Accelerate（見 docs/ARCHITECTURE.md）。
        .target(name: "VBTCore"),
        // 影片解碼與 Vision 追蹤；依賴 VBTCore，不可反向。
        .target(name: "VBTVision", dependencies: ["VBTCore"]),
        .testTarget(name: "VBTCoreTests", dependencies: ["VBTCore"]),
        .testTarget(name: "VBTVisionTests", dependencies: ["VBTVision"]),
    ]
)
