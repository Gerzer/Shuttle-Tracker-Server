//
//  Bus.swift
//  Shuttle Tracker Server
//
//  Created by Gabriel Jacoby-Cooper on 9/21/20.
//

import Vapor
import Fluent

final class Bus: Hashable, Model {
	
	final class Location: Equatable, Content, Fields {
		
		enum LocationType: String, Codable {
			
			case system = "system"
			case user = "user"
			
		}
		
		@ID(custom: "id", generatedBy: .user) var id: UUID?
		
		@Field(key: "date") var date: Date
		
		@Field(key: "coordinate") var coordinate: Coordinate
		
		@Enum(key: "type") var type: LocationType
		
		init() { }
		
		init(id: UUID, date: Date, coordinate: Coordinate, type: LocationType) {
			self.id = id
			self.date = date
			self.coordinate = coordinate
			self.type = type
		}
		
		static func == (_ leftLocation: Bus.Location, _ rightLocation: Bus.Location) -> Bool {
			return leftLocation.id == rightLocation.id
		}
		
	}
	
	static let schema = "buses"
	
	var response: BusResponse? {
		get {
			guard let location = self.locations.resolvedLocation else {
				return nil
			}
			return BusResponse(id: self.id ?? 0, location: location)
		}
	}
	
	@ID(custom: "id", generatedBy: .user) var id: Int?
	
	@Field(key: "locations") var locations: [Location]
	
	@OptionalField(key: "congestion") var congestion: Int?
	
	init() { }
	
	init(id: Int, locations: [Location] = []) {
		self.id = id
		self.locations = locations
	}
	
	static func == (_ leftBus: Bus, _ rightBus: Bus) -> Bool {
		return leftBus.id == rightBus.id
	}
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(self.id)
	}
	
}

struct BusResponse: Content {
	
	var id: Int
	
	var location: Bus.Location
	
}

extension Collection where Element == Bus {
	
	func save(on database: Database) {
		self.forEach { (bus) in
			_ = bus.save(on: database)
		}
	}
	
}

extension Set where Element == Bus {
	
	static func download(application: Application, _ busesCallback:  @escaping (Set<Bus>) -> Void) {
		_ = application.client.get("https://shuttles.rpi.edu/datafeed")
			.map { (response) in
				guard let length = response.body?.readableBytes, let data = response.body?.getData(at: 0, length: length), let rawString = String(data: data, encoding: .utf8) else {
					return
				}
				let buses = rawString.split(separator: "\r\n").dropFirst().dropLast().compactMap { (rawLine) -> Bus? in
					guard let idRange = rawLine.range(of: #"(?<=(Vehicle\sID:))\d+"#, options: [.regularExpression]), let id = Int(rawLine[idRange]) else {
						return nil
					}
					guard let latitudeRange = rawLine.range(of: #"(?<=(lat:))-?\d+\.\d+"#, options: [.regularExpression]), let latitude = Double(rawLine[latitudeRange]) else {
						return nil
					}
					guard let longitudeRange = rawLine.range(of: #"(?<=(lon:))-?\d+\.\d+"#, options: [.regularExpression]), let longitude = Double(rawLine[longitudeRange]) else {
						return nil
					}
					guard let timeRange = rawLine.range(of: #"(?<=(time:))\d+"#, options: [.regularExpression]), let dateRange = rawLine.range(of: #"(?<=(date:))\d{8}"#, options: [.regularExpression]) else {
						return nil
					}
					let formatter = DateFormatter()
					formatter.dateFormat = "HHmmss'|'MMddyyyy"
					formatter.timeZone = TimeZone(abbreviation: "UTC")!
					let dateString = "\(rawLine[timeRange])|\(rawLine[dateRange])"
					let date = formatter.date(from: dateString)!
					let coordinate = Coordinate(latitude: latitude, longitude: longitude)
					let location = Bus.Location(id: UUID(), date: date, coordinate: coordinate, type: .system)
					return Bus(id: id, locations: [location])
				}
				busesCallback(Set(buses))
			}
	}
	
}

extension Collection where Element == Bus.Location {
	
	var systemLocation: Bus.Location? {
		get {
			return self.reversed().first { (location) -> Bool in
				return location.type == .system
			}
		}
	}
	
	var userLocation: Bus.Location? {
		get {
			let userLocations = self.filter { (location) -> Bool in
				return location.type == .user
			}
			guard userLocations.count > 0 else {
				return nil
			}
			let newestLocation = userLocations.max { (firstLocation, secondLocation) -> Bool in
				return firstLocation.date.compare(secondLocation.date) == .orderedAscending
			}
			let zeroCoordinate = Coordinate(latitude: 0, longitude: 0)
			var coordinate = userLocations.reduce(into: zeroCoordinate) { (coordinate, location) in
				coordinate += location.coordinate
			}
			coordinate /= Double(userLocations.count)
			guard let userCoordinate = coordinate == zeroCoordinate ? nil : coordinate else {
				return nil
			}
			return Bus.Location(id: UUID(), date: newestLocation?.date ?? Date(), coordinate: userCoordinate, type: .user)
		}
	}
	
	var resolvedLocation: Bus.Location? {
		get {
			return self.userLocation ?? self.systemLocation
		}
	}
	
}

extension Array: Mergeable where Element == Bus.Location {
	
	mutating func merge(with otherLocations: [Bus.Location]) {
		otherLocations.forEach { (location) in
			if let index = self.firstIndex(of: location) {
				self.remove(at: index)
			}
			self.append(location)
		}
	}
	
}
