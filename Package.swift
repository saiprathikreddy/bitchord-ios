// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BitChord",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .executable(
            name: "BitChord",
            targets: ["BitChord"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "BitChord",
            path: "Sources"
        )
    ]
)
