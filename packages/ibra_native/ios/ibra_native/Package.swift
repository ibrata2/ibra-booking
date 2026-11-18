// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ibra_native",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "ibra-native", targets: ["ibra_native"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "ibra_native",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
