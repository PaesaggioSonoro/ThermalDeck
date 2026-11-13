// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThermalDeck",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "ThermalDeck", targets: ["ThermalDeck"]),
        .executable(name: "thermal-probe", targets: ["ThermalProbe"]),
        .executable(name: "thermal-fan-helper", targets: ["ThermalFanHelper"]),
        .library(name: "ThermalCore", targets: ["ThermalCore"]),
        .library(name: "ControlSimulation", targets: ["ControlSimulation"]),
        .library(name: "HardwareAccess", targets: ["HardwareAccess"])
    ],
    targets: [
        .target(name: "ThermalCore"),
        .target(name: "ControlSimulation", dependencies: ["ThermalCore"]),
        .target(name: "SMCRead", linkerSettings: [.linkedFramework("IOKit")]),
        .target(name: "HardwareAccess", dependencies: ["ThermalCore", "SMCRead"]),
        .executableTarget(name: "ThermalProbe", dependencies: ["HardwareAccess", "ThermalCore"]),
        .executableTarget(name: "ThermalFanHelper", dependencies: ["HardwareAccess"]),
        .executableTarget(name: "ThermalDeck", dependencies: ["HardwareAccess", "ThermalCore", "ControlSimulation"]),
        .testTarget(name: "ThermalCoreTests", dependencies: ["ThermalCore", "HardwareAccess", "ControlSimulation"]),
        .testTarget(name: "ThermalDeckTests", dependencies: ["ThermalDeck", "ThermalCore"])
    ]
)
