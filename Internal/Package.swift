// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Internal",
	 platforms: [
				 .macOS(.v14),
				 .iOS(.v14),
				 .watchOS(.v10)
		  ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Internal",
            targets: ["Internal"]
        ),
    ],
	 dependencies: [
		.package(url: "https://github.com/ios-tooling/Suite", .upToNextMajor(from: "1.3.17")),
	 ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Internal", dependencies: [
					.product(name: "Suite", package: "Suite"),
			 ]
        ),
		  .testTarget(
				name: "InternalTests",
				dependencies: ["Internal"]
		  ),
    ]
)
