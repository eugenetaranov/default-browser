// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DefaultBrowserRouter",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
    ],
    targets: [
        // Pure, testable routing/config logic (no AppKit side effects).
        .target(
            name: "RouterCore",
            dependencies: ["Yams"]
        ),
        // Headless AppKit executable that receives URLs and launches browsers.
        .executableTarget(
            name: "DefaultBrowserRouter",
            dependencies: ["RouterCore"]
        ),
        // Self-contained test runner (plain Swift assertions) so the suite runs with
        // only Command Line Tools installed — the CLT toolchain lacks a buildable
        // XCTest module. Run with: `swift run RouterTests`.
        .executableTarget(
            name: "RouterTests",
            dependencies: ["RouterCore"]
        )
    ]
)
