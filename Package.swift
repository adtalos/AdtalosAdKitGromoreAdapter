// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AdtalosAdKitGromoreAdapter",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "AdtalosAdKitGromoreAdapter",
            targets: ["AdtalosAdKitGromoreAdapter"]
        )
    ],
    dependencies: [
	
    ],
    targets: [
        .binaryTarget(
            name: "AdtalosAdKitGromoreAdapter",
	    path: "AdtalosAdKitGromoreAdapter.xcframework"
        )
    ]
)


