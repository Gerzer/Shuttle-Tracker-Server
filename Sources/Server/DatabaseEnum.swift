//
//  DatabaseEnum.swift
//  Shuttle Tracker Server
//
//  Created by Gabriel Jacoby-Cooper on 1/14/23.
//

import Fluent
import Foundation

/// An enumeration that can be represented in a SQL database via Fluent.
protocol DatabaseEnum: CaseIterable {
	
	/// The name of this enumeration.
	static var name: String { get }
	
	/// Creates a database representation of this enumeration.
	/// - Parameter database: The database in which to create the representation.
	/// - Returns: The representation.
	static func representation(for database: some Database) async throws -> DatabaseSchema.DataType
	
}

extension DatabaseEnum where Self: RawRepresentable, RawValue == String {
	
	static func representation(for database: some Database) async throws -> DatabaseSchema.DataType {
		var builder = database.enum(self.name)
		guard case .enum(let `enum`) = try await builder.read() else {
			throw DatabaseEnumError.notAnEnum
		}
		
		// Add new cases that appear in the source code but not in the database
		for enumCase in self.allCases where !`enum`.cases.contains(enumCase.rawValue) {
			builder = builder.case(enumCase.rawValue)
		}
		
		// Delete old cases that appear in the database but not in the source code
		for rawValue in `enum`.cases {
			let doDelete = !self.allCases.contains { (enumCase) in
				return enumCase.rawValue == rawValue
			}
			if doDelete {
				builder = builder.deleteCase(rawValue)
			}
		}
		
		if `enum`.cases.isEmpty { // The enumerated type probably doesn’t exist yet in the database.
			return try await builder.create()
		} else { // The enumerated type probably already exists in the database.
			return try await builder.update()
		}
	}
	
}

enum DatabaseEnumError: LocalizedError {
	
	case notAnEnum
	
	var errorDescription: String? {
		get {
			switch self {
			case .notAnEnum:
				return "The representation is not an enumeration."
			}
		}
	}
	
}
