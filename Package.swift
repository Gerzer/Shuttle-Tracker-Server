// swift-tools-version:5.7

import PackageDescription

let package = Package(
	name: "Shuttle Tracker Server",
	platforms: [
		.macOS(.v13)
	],
	dependencies: [
		.package(
			url: "https://github.com/apple/swift-algorithms.git",
			from: "1.2.0"
		),
		.package(
			url: "https://github.com/vapor/vapor.git",
			from: "4.92.0"
		),
		.package(
			url: "https://github.com/vapor/queues.git",
			from: "1.13.0"
		),
		.package(
			url: "https://github.com/vapor/fluent.git",
			from: "4.9.0"
		),
		.package(
			url: "https://github.com/vapor/fluent-sqlite-driver.git",
			from: "4.6.0"
		),
		.package(
			url: "https://github.com/vapor/fluent-postgres-driver.git",
			from: "2.8.0"
		),
		.package(
			url: "https://github.com/vapor/apns.git",
			from: "4.0.0"
		),
		.package(
			url: "https://github.com/m-barthelemy/vapor-queues-fluent-driver.git",
			from: "3.0.0-beta.1"
		),
		.package(
			url: "https://github.com/malcommac/UAParserSwift.git",
			from: "1.2.0"
		),
		.package(
			url: "https://github.com/mapbox/turf-swift.git",
			from: "2.8.0"
		),
		.package(
			url: "https://github.com/wtg/JSONParser.git",
			from: "1.3.0"
		),
		.package(
			url: "https://github.com/vincentneo/CoreGPX.git",
			from: "0.9.2"
		)
	],
	targets: [
		.executableTarget(
			name: "Server",
			dependencies: [
				.product(
					name: "Algorithms",
					package: "swift-algorithms"
				),
				.product(
					name: "Vapor",
					package: "vapor"
				),
				.product(
					name: "Queues",
					package: "queues"
				),
				.product(
					name: "Fluent",
					package: "fluent"
				),
				.product(
					name: "FluentSQLiteDriver",
					package: "fluent-sqlite-driver"
				),
				.product(
					name: "FluentPostgresDriver",
					package: "fluent-postgres-driver"
				),
				.product(
					name: "QueuesFluentDriver",
					package: "vapor-queues-fluent-driver"
				),
				.product(
					name: "VaporAPNS",
					package: "apns"
				),
				.product(
					name: "CoreGPX",
					package: "CoreGPX"
				),
				.product(
					name: "JSONParser",
					package: "JSONParser"
				),
				.product(
					name: "UAParserSwift",
					package: "UAParserSwift"
				),
				.product(
					name: "Turf",
					package: "turf-swift"
				)
			]
		)
	]
)
