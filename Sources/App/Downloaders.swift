//
//  Downloaders.swift
//  Shuttle Tracker Server
//
//  Created by Gabriel Jacoby-Cooper on 11/1/21.
//

import Vapor
import Fluent

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif // canImport(FoundationNetworking)

enum Downloaders {
	
	/// Download the latest system bus data.
	/// - Parameters:
	///   - application: The current application object.
	///   - busesCallback: A callback that's given a `Set<Bus>` instance with new bus objects. Note that these bus objects will **not** contain any user-reported location or congestion data and therefore must be separately merged with any existing bus data.
	static func getBuses(on application: Application) async throws -> some AsyncSequence {
		let buses = Constants.datafeedURL.lines
			.dropFirst()
			.compactMap { (line) -> Bus? in
				guard let backendIDRange = line.range(of: #"(?<=(Vehicle\sID:))\d+"#, options: [.regularExpression]) else {
					return nil
				}
				guard let latitudeRange = line.range(of: #"(?<=(lat:))-?\d+\.\d+"#, options: [.regularExpression]), let latitude = Double(line[latitudeRange]) else {
					return nil
				}
				guard let longitudeRange = line.range(of: #"(?<=(lon:))-?\d+\.\d+"#, options: [.regularExpression]), let longitude = Double(line[longitudeRange]) else {
					return nil
				}
				guard let timeRange = line.range(of: #"(?<=(time:))\d+"#, options: [.regularExpression]), let dateRange = line.range(of: #"(?<=(date:))\d{8}"#, options: [.regularExpression]) else {
					return nil
				}
				let backendID = String(line[backendIDRange])
				let id = Buses.sharedInstance.busIDMap[backendID]
				let formatter = DateFormatter()
				formatter.dateFormat = "HHmmss'|'MMddyyyy"
				formatter.timeZone = TimeZone(abbreviation: "UTC")!
				let dateString = "\(line[timeRange])|\(line[dateRange])"
				guard var date = formatter.date(from: dateString) else {
					return nil
				}
				let coordinate = Coordinate(latitude: latitude, longitude: longitude)
				if date > Date.now {
					let oldBus = try await Bus.query(on: application.db)
						.filter(\.$id == id)
						.first()
					if let oldLocation = oldBus?.locations.resolved, oldLocation.coordinate == coordinate {
						date = oldLocation.date
					} else {
						date = Date.now
					}
				}
				let location = Bus.Location(id: UUID(), date: date, coordinate: coordinate, type: .system)
				return Bus(id: id, locations: [location])
			}
		return buses
	}
	
}
