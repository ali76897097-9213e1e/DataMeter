// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DataMeter",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DataMeterCore", targets: ["DataMeterCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.10.0")
    ],
    targets: [
        .target(name: "DataMeterCore", dependencies: [.product(name: "GRDB", package: "GRDB.swift")], path: "DataMeterCore"),
        .testTarget(name: "DataMeterCoreTests", dependencies: ["DataMeterCore"], path: "DataMeterCoreTests")
    ]
)
