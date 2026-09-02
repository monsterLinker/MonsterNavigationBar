// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MonsterNavigationBar",
    platforms: [.iOS(.v12)],
    products: [
        .library(name: "MonsterNavigationBar", targets: ["MonsterNavigationBar"])
    ],
    targets: [
        .target(name: "MonsterNavigationBar", path: "Sources/MonsterNavigationBar"),
        .testTarget(
            name: "MonsterNavigationBarTests",
            dependencies: ["MonsterNavigationBar"],
            path: "Tests/MonsterNavigationBarTests"
        )
    ]
)
