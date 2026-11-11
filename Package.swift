// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DRETerm",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", exact: "1.18.0")
    ],
    targets: [
        .executableTarget(
            name: "DRETerm",
            dependencies: [.product(name: "SwiftTerm", package: "SwiftTerm")],
            path: "Sources/DRETerm"
        )
    ]
)
