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
        // 槓片偵測 Core ML 模型（YOLOv8n→Core ML，見 DECISIONS D-033）隨套件打包，執行時編譯載入。
        .target(
            name: "VBTVision",
            dependencies: ["VBTCore"],
            resources: [.copy("Resources/BarbellDetector.mlpackage")]
        ),
        .testTarget(name: "VBTCoreTests", dependencies: ["VBTCore"]),
        .testTarget(name: "VBTVisionTests", dependencies: ["VBTVision"]),
    ]
)
