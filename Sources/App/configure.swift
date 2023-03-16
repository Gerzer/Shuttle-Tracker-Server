//
//  configure.swift
//  Shuttle Tracker Server
//
//  Created by Gabriel Jacoby-Cooper on 9/21/20.
//

import APNS
import FluentPostgresDriver
import FluentSQLiteDriver
import NIOSSL
import Queues
import QueuesFluentDriver
import Vapor

public func configure(_ application: Application) async throws {
	// MARK: - Middleware
	application.middleware.use(
		CORSMiddleware(
			configuration: .default()
		)
	)
	application.middleware.use(
		FileMiddleware(
			publicDirectory: application.directory.publicDirectory
		)
	)
	
	// MARK: - Databases
	application.databases.use(
		.sqlite(),
		as: .sqlite,
		isDefault: false
	)
	if let postgresURLString = ProcessInfo.processInfo.environment["DATABASE_URL"], let postgresURL = URL(string: postgresURLString) {
		application.databases.use(
			try .postgres(url: postgresURL),
			as: .psql,
			isDefault: false
		)
	} else {
		let postgresHostname = ProcessInfo.processInfo.environment["POSTGRES_HOSTNAME"]!
		let postgresUsername = ProcessInfo.processInfo.environment["POSTGRES_USERNAME"]!
		let postgresPassword = ProcessInfo.processInfo.environment["POSTGRES_PASSWORD"] ?? ""
		
		// TODO: Make a new database during the setup process
		// For now, we’re using the default PostgreSQL database for deployment compatibility reasons, but we should in the future switch to a non-default, unprotected database.
		application.databases.use(
			.postgres(
				hostname: postgresHostname,
				username: postgresUsername,
				password: postgresPassword
			),
			as: .psql,
			isDefault: false
		)
	}
	
	// MARK: - Migrations
	application.migrations.add(
		CreateBuses(),
		CreateRoutes(),
		CreateStops(),
		JobModelMigrate(),
		to: .sqlite
	) // Add to the SQLite database
	try await application.autoMigrate()
	
	let migrator = try await VersionedMigrator(database: application.db(.psql))
	try await migrator.migrate(CreateAnalyticsEntries())
	try await migrator.migrate(CreateAnnouncements())
	try await migrator.migrate(CreateAPNSDevices())
	try await migrator.migrate(CreateLogs())
	try await migrator.migrate(CreateMilestones())
	
	// MARK: - Jobs
	application.queues.use(.fluent(.sqlite, useSoftDeletes: false))
	application.queues
		.schedule(BusDownloadingJob())
		.minutely()
		.at(0)
	application.queues
		.schedule(GPXImportingJob())
		.daily()
		.at(.midnight)
	application.queues
		.schedule(LocationRemovalJob())
		.everySecond()
	application.queues
		.schedule(RestartJob())
		.at(Date() + 21600)
	try application.queues.startInProcessJobs()
	try application.queues.startScheduledJobs()
	
	// MARK: - APNS
	if let apnsKeyPath = ProcessInfo.processInfo.environment["APNS_KEY"] {
		application.apns.containers.use(
			APNSClientConfiguration(
				authenticationMethod: .jwt(
					privateKey: try .loadFrom(filePath: apnsKeyPath)!,
					keyIdentifier: "X43K3R94T2", // FIXME: Read from environment variable
					teamIdentifier: "SYBLH277NF" // FIXME: Read from environment variable
				),
				environment: .production // FIXME: Detect staging environment and set to .sandbox
			),
			eventLoopGroupProvider: .shared(application.eventLoopGroup),
			responseDecoder: JSONDecoder(),
			requestEncoder: JSONEncoder(),
			backgroundActivityLogger: application.logger,
			as: .default
		)
	}
	
	// MARK: - TLS
	if FileManager.default.fileExists(atPath: "tls") {
		print("TLS directory detected!")
		try application.http.server.configuration.tlsConfiguration = .makeServerConfiguration(
			certificateChain: [
				.certificate(
					NIOSSLCertificate(
						file: "\(FileManager.default.currentDirectoryPath)/tls/server.crt",
						format: .pem
					)
				)
			],
			privateKey: .privateKey(
				NIOSSLPrivateKey(
					file: "\(FileManager.default.currentDirectoryPath)/tls/server.key",
					format: .pem
				)
			)
		)
	} else if let domain = ProcessInfo.processInfo.environment["DOMAIN"] {
		try application.http.server.configuration.tlsConfiguration = .makeServerConfiguration(
			certificateChain: [
				.certificate(
					NIOSSLCertificate(
						file: "/etc/letsencrypt/live/\(domain)/fullchain.pem",
						format: .pem
					)
				)
			],
			privateKey: .file(
				"/etc/letsencrypt/live/\(domain)/privkey.pem"
			)
		)
	}
	
	// MARK: - Startup
	for busID in Buses.shared.allBusIDs {
		try await Bus(id: busID)
			.save(on: application.db(.sqlite))
	}
	try? await BusDownloadingJob()
		.run(context: application.queues.queue.context)
	try await GPXImportingJob()
		.run(context: application.queues.queue.context)
	try routes(application)
}
