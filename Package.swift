// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FFPSJiOS",
    platforms: [.iOS(.v17)],
    products: [
        // xtool empaqueta productos library; no se usa un proyecto .xcodeproj.
        .library(name: "FFPSJApp", targets: ["FFPSJApp"]),
        .library(name: "FFPSJLiveActivity", targets: ["FFPSJLiveActivity"])
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0")
    ],
    targets: [
        .target(name: "FFPSJDomain"),
        .target(
            name: "FFPSJData",
            dependencies: [
                "FFPSJDomain",
                .product(name: "Supabase", package: "supabase-swift")
            ]
        ),
        .target(
            name: "FFPSJApp",
            dependencies: ["FFPSJDomain", "FFPSJData"]
        ),
        .target(name: "FFPSJLiveActivity", dependencies: ["FFPSJDomain"]),
        .testTarget(name: "FFPSJDomainTests", dependencies: ["FFPSJDomain"])
    ]
)
