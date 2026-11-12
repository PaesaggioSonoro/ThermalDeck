// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThermalDeck",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "ThermalDeck", targets: ["ThermalDeck"]),
        .library(name: "ThermalCore", targets: ["ThermalCore"]),
    ],
    targets: [
        .target(name: "ThermalCore"),
        .executableTarget(name: "ThermalDeck", dependencies: ["ThermalCore"]),
        .testTarget(name: "ThermalCoreTests", dependencies: ["ThermalCore"])
    ]
)
