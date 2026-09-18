import Foundation
import CoreLocation

struct SavedMobileRoute: Codable, Identifiable {
    struct Point: Codable {
        let latitude: Double
        let longitude: Double

        init(_ coordinate: CLLocationCoordinate2D) {
            latitude = coordinate.latitude
            longitude = coordinate.longitude
        }

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    let id: UUID
    var name: String
    var points: [Point]
    var speedKPH: Double
    let createdAt: Date
    var isBuiltIn: Bool

    init(
        id: UUID = UUID(),
        name: String,
        coordinates: [CLLocationCoordinate2D],
        speedKPH: Double,
        createdAt: Date = Date(),
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.points = coordinates.map(Point.init)
        self.speedKPH = speedKPH
        self.createdAt = createdAt
        self.isBuiltIn = isBuiltIn
    }

    var coordinates: [CLLocationCoordinate2D] { points.map(\.coordinate) }

    var plan: MobileRoutePlan {
        MobileRoutePlan(name: name, coordinates: coordinates, speedKPH: speedKPH)
    }
}

enum SavedRouteStore {
    private static let fileName = "saved-routes.json"
    static func load() -> [SavedMobileRoute] {
        guard let data = try? Data(contentsOf: fileURL),
              let routes = try? JSONDecoder().decode([SavedMobileRoute].self, from: data) else {
            return []
        }
        return routes.filter { !$0.isBuiltIn }
    }

    @discardableResult
    static func save(
        name: String,
        coordinates: [CLLocationCoordinate2D],
        speedKPH: Double
    ) throws -> SavedMobileRoute {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, coordinates.count >= 2 else {
            throw SavedRouteError.invalidRoute
        }

        var routes = load()
        let route = SavedMobileRoute(
            name: trimmed,
            coordinates: coordinates,
            speedKPH: speedKPH
        )

        // A repeated name means "update this route", avoiding a pile of nearly
        // identical copies after the user edits and saves again.
        if let index = routes.firstIndex(where: {
            $0.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            routes[index] = route
        } else {
            routes.append(route)
        }
        try write(routes)
        return route
    }

    static func delete(id: UUID) throws {
        let routes = load().filter { $0.id != id }
        try write(routes)
    }

    private static var fileURL: URL {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Routes", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
    }

    private static func write(_ routes: [SavedMobileRoute]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(routes)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    private enum SavedRouteError: LocalizedError {
        case invalidRoute
        var errorDescription: String? { "路線名稱或座標無效" }
    }
}
