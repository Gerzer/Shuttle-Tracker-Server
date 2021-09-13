//
//  LocationRemovalJob.swift
//  Shuttle Tracker Server
//
//  Created by Gabriel Jacoby-Cooper on 9/22/20.
//

import Queues

/// A job that removes outdated location data.
struct LocationRemovalJob: ScheduledJob {
	
	func run(context: QueueContext) -> EventLoopFuture<Void> {
		_ = Bus.query(on: context.application.db)
			.all()
			.mapEach { (bus) in
				let oldLocations = bus.locations.filter { (location) in
					return location.type == .user && location.date.timeIntervalSinceNow < -30
				}
				let oldLocationsIndices = oldLocations.compactMap { (location) in
					return bus.locations.firstIndex(of: location)
				}
				oldLocationsIndices.forEach { (index) in
					bus.locations.remove(at: index)
				}
				_ = bus.update(on: context.application.db)
			}
		return context.eventLoop.future()
	}
	
}
