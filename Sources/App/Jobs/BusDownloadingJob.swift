//
//  BusDownloadingJob.swift
//  Shuttle Tracker Server
//
//  Created by Gabriel Jacoby-Cooper on 9/26/20.
//

import Queues

/// A job that downloads the latest system bus data.
struct BusDownloadingJob: ScheduledJob {
	
	func run(context: QueueContext) -> EventLoopFuture<Void> {
		Set<Bus>.download(application: context.application) { (buses) in
			var newBuses = buses
			Bus.query(on: context.application.db)
				.all()
				.mapEachCompact { (existingBus) in
					if let newBus = newBuses.remove(existingBus) {
						existingBus.locations.merge(with: newBus.locations)
						_ = existingBus.update(on: context.application.db)
					}
				}
				.whenSuccess { (_) in
					newBuses.save(on: context.application.db)
				}
		}
		return context.eventLoop.future()
	}
	
}
