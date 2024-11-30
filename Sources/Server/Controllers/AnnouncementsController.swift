//
//  AnnouncementsController.swift
//  Shuttle Tracker Server
//
//  Created by Gabriel Jacoby-Cooper on 1/10/24.
//

import APNSCore
import Vapor

/// A structure that registers routes for announcements.
/// - Important: This structure registers routes on the index path of its provided routes builder, so make sure to enclose it in a named routes group to avoid path collisions.
/// - Remark: In the context of this structure, the term “route” refers to an HTTP route, not a shuttle route.
struct AnnouncementsController<DecoderType>: RouteCollection where DecoderType: ContentDecoder {
	
	private let decoder: DecoderType
	
	init(decoder: DecoderType) {
		self.decoder = decoder
	}
	
	func boot(routes: any RoutesBuilder) throws {
		routes.post(use: self.create(_:))
		routes.get(use: self.read(_:))
		try routes.register(collection: AnnouncementController(decoder: self.decoder))
	}
	
	private func create(_ request: Request) async throws -> Announcement {
		let announcement = try request.content.decode(Announcement.self, using: self.decoder)

		// Check if the announcement start date is at least an hour in the future
		let now = Date()
		let timeUntilStart = announcement.start.timeIntervalSince(now)
		if timeUntilStart > 3600 { // More than an hour ahead
			// Schedule the notification job here
			let job = SendAnnouncementNotificationJob(announcementID: announcement.id)
			// Calculate the delay for the job based on the announcement's start date
			let delay = DispatchTimeInterval.seconds(Int(timeUntilStart))
			application.queues.dispatch(job, after: delay)
		} else {

		}


		// new changes 2/13 

		// ** announcement json string ** 
		guard let data = ("\(announcement.id) || \(announcement.subject) ||  \(announcement.start) || \(announcement.end) || 
		\(announcement.scheduleType) || \(announcement.body) || \(announcement.interruptionLevel)").data(using: .utf8) else {
			throw Abort(.internalServerError)
		}

		if try CryptographyUtilities.verify(signature: announcement.signature, of: data) {
			try await announcement.save(on: request.db(.psql))
			
			// Send a push notification to all Apple devices
			let devices = try await APNSDevice
				.query(on: request.db(.psql))
				.all()
			request.logger.log(level: .info, "[\(#fileID):\(#line) \(#function)] Sending a push notification to \(devices.count) devices…")
			try await withThrowingTaskGroup(of: Void.self) { (taskGroup) in
				let interruptionLevel: APNSAlertNotificationInterruptionLevel
				switch announcement.interruptionLevel {
				case .passive:
					interruptionLevel = .passive
				case .active:
					interruptionLevel = .active
				case .timeSensitive:
					interruptionLevel = .timeSensitive
				case .critical:
					interruptionLevel = .critical
				}
				let payload = try announcement.apnsPayload
				for device in devices {
					let deviceToken = device.token
					taskGroup.addTask {
						do {
							try await request.apns.client.sendAlertNotification(
								APNSAlertNotification(
									alert: APNSAlertNotificationContent(
										title: .raw("Announcement"),
										subtitle: .raw(announcement.subject),
										body: .raw(announcement.body),
										launchImage: nil
									),
									expiration: .none,
									priority: .immediately,
									topic: Constants.apnsTopic,
									payload: payload,
									sound: .default,
									mutableContent: 1,
									interruptionLevel: interruptionLevel,
									apnsID: announcement.id
								),
								deviceToken: deviceToken
							)
						} catch {
							request.logger.log(level: .error, "[\(#fileID):\(#line) \(#function)] Failed to send APNS notification: \(error)")
						}
					}
				}
			}
			
			return announcement
		} else {
			throw Abort(.forbidden)
		}
	}
	
	private func read(_ request: Request) async throws -> [Announcement] {
		return try await Announcement
			.query(on: request.db(.psql))
			.all()
	}
	
}
