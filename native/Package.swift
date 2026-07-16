// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YanhengNative",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "YanhengNative", type: .dynamic, targets: ["YanhengNative"])
    ],
    targets: [
        .target(
            name: "YanhengNative",
            linkerSettings: [.linkedFramework("Security")]
        ),
        .testTarget(name: "YanhengNativeTests", dependencies: ["YanhengNative"])
    ]
)
