// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThermalDeck",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "ThermalDeck", targets: ["ThermalDeck"]),
        .executable(name: "thermal-probe", targets: ["ThermalProbe"]),
        .library(name: "ThermalCore", targets: ["ThermalCore"]),
        .library(name: "HardwareAccess", targets: ["HardwareAccess"])
    ],
    targets: [
        .target(name: "ThermalCore"),
        .target(name: "SMCRead", linkerSettings: [.linkedFramework("IOKit")]),
        .target(name: "HardwareAccess", dependencies: ["ThermalCore", "SMCRead"]),
        .executableTarget(name: "ThermalProbe", dependencies: ["HardwareAccess", "ThermalCore"]),
        .executableTarget(name: "ThermalDeck", dependencies: ["HardwareAccess", "ThermalCore"]),
        .testTarget(name: "ThermalCoreTests", dependencies: ["ThermalCore", "HardwareAccess"])
    ]
)
