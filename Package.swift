// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MainMic",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MainMic",
            path: "Sources/MainMic",
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
