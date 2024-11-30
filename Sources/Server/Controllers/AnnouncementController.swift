//
//  AnnouncementController.swift
//  Shuttle Tracker Server
//
//  Created by Gabriel Jacoby-Cooper on 1/10/24.
//

import FluentKit
import Vapor

/// A structure that registers routes for managing individual announcements.
/// - Remark: In the context of this structure, the term “route” refers to an HTTP route, not a shuttle route.
struct AnnouncementController<DecoderType>: RouteCollection where DecoderType: ContentDecoder {
	
	private let decoder: DecoderType
	
	init(decoder: DecoderType) {
		self.decoder = decoder
	}
	
	func boot(routes: any RoutesBuilder) throws {
		routes.group(":id") { (routes) in
			routes.get(use: self.read(_:))
			routes.delete(use: self.delete(_:))
		}
	}
	
	private func read(_ request: Request) async throws -> Announcement {
		guard let id = request.parameters.get("id", as: UUID.self) else {
			throw Abort(.badRequest)
		}
		let announcement = try await Announcement
			.query(on: request.db(.psql))
			.filter(\.$id == id)
			.first()
		guard let announcement else {
			throw Abort(.notFound)
        } //testing
		return announcement
	}
	
	private func delete(_ request: Request) async throws -> UUID {
		guard let id = request.parameters.get("id", as: UUID.self) else {
			throw Abort(.badRequest)
		}
		let deletionRequest = try request.content.decode(Announcement.DeletionRequest.self, using: self.decoder)
		guard let data = id.uuidString.data(using: .utf8) else {
			throw Abort(.internalServerError)
		}
		if try CryptographyUtilities.verify(signature: deletionRequest.signature, of: data) {
			try await Announcement
				.query(on: request.db(.psql))
				.filter(\.$id == id)
				.delete()
			return id
		} else {
			throw Abort(.forbidden)
		}
	}
	
}
