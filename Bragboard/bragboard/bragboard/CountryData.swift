//
//  CountryData.swift
//  bragboard
//
//  Country data model and list for Countries Served widget
//

import Foundation
import CoreLocation

// MARK: - Country Model
struct Country: Identifiable, Codable, Hashable {
    let id: String // ISO country code
    let name: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Country Data Service
struct CountryDataService {
    static let shared = CountryDataService()

    // Default location: Charlottetown, PEI, Canada
    static let defaultCountry = Country(
        id: "CA",
        name: "Canada",
        latitude: 46.2382,  // Charlottetown, PEI coordinates
        longitude: -63.1311
    )

    // Comprehensive list of countries with their capital city coordinates
    let allCountries: [Country] = [
        // North America
        Country(id: "CA", name: "Canada", latitude: 46.2382, longitude: -63.1311), // Default: Charlottetown, PEI
        Country(id: "US", name: "United States", latitude: 38.9072, longitude: -77.0369),
        Country(id: "MX", name: "Mexico", latitude: 19.4326, longitude: -99.1332),

        // South America
        Country(id: "BR", name: "Brazil", latitude: -15.8267, longitude: -47.9218),
        Country(id: "AR", name: "Argentina", latitude: -34.6037, longitude: -58.3816),
        Country(id: "CL", name: "Chile", latitude: -33.4489, longitude: -70.6693),
        Country(id: "CO", name: "Colombia", latitude: 4.7110, longitude: -74.0721),
        Country(id: "PE", name: "Peru", latitude: -12.0464, longitude: -77.0428),
        Country(id: "VE", name: "Venezuela", latitude: 10.4806, longitude: -66.9036),

        // Europe
        Country(id: "GB", name: "United Kingdom", latitude: 51.5074, longitude: -0.1278),
        Country(id: "FR", name: "France", latitude: 48.8566, longitude: 2.3522),
        Country(id: "DE", name: "Germany", latitude: 52.5200, longitude: 13.4050),
        Country(id: "IT", name: "Italy", latitude: 41.9028, longitude: 12.4964),
        Country(id: "ES", name: "Spain", latitude: 40.4168, longitude: -3.7038),
        Country(id: "NL", name: "Netherlands", latitude: 52.3676, longitude: 4.9041),
        Country(id: "BE", name: "Belgium", latitude: 50.8503, longitude: 4.3517),
        Country(id: "CH", name: "Switzerland", latitude: 46.9480, longitude: 7.4474),
        Country(id: "AT", name: "Austria", latitude: 48.2082, longitude: 16.3738),
        Country(id: "SE", name: "Sweden", latitude: 59.3293, longitude: 18.0686),
        Country(id: "NO", name: "Norway", latitude: 59.9139, longitude: 10.7522),
        Country(id: "DK", name: "Denmark", latitude: 55.6761, longitude: 12.5683),
        Country(id: "FI", name: "Finland", latitude: 60.1699, longitude: 24.9384),
        Country(id: "PL", name: "Poland", latitude: 52.2297, longitude: 21.0122),
        Country(id: "CZ", name: "Czech Republic", latitude: 50.0755, longitude: 14.4378),
        Country(id: "PT", name: "Portugal", latitude: 38.7223, longitude: -9.1393),
        Country(id: "GR", name: "Greece", latitude: 37.9838, longitude: 23.7275),
        Country(id: "IE", name: "Ireland", latitude: 53.3498, longitude: -6.2603),

        // Asia
        Country(id: "CN", name: "China", latitude: 39.9042, longitude: 116.4074),
        Country(id: "JP", name: "Japan", latitude: 35.6762, longitude: 139.6503),
        Country(id: "IN", name: "India", latitude: 28.6139, longitude: 77.2090),
        Country(id: "KR", name: "South Korea", latitude: 37.5665, longitude: 126.9780),
        Country(id: "SG", name: "Singapore", latitude: 1.3521, longitude: 103.8198),
        Country(id: "MY", name: "Malaysia", latitude: 3.1390, longitude: 101.6869),
        Country(id: "TH", name: "Thailand", latitude: 13.7563, longitude: 100.5018),
        Country(id: "VN", name: "Vietnam", latitude: 21.0285, longitude: 105.8542),
        Country(id: "ID", name: "Indonesia", latitude: -6.2088, longitude: 106.8456),
        Country(id: "PH", name: "Philippines", latitude: 14.5995, longitude: 120.9842),
        Country(id: "PK", name: "Pakistan", latitude: 33.6844, longitude: 73.0479),
        Country(id: "BD", name: "Bangladesh", latitude: 23.8103, longitude: 90.4125),
        Country(id: "AE", name: "United Arab Emirates", latitude: 24.4539, longitude: 54.3773),
        Country(id: "SA", name: "Saudi Arabia", latitude: 24.7136, longitude: 46.6753),
        Country(id: "IL", name: "Israel", latitude: 31.7683, longitude: 35.2137),
        Country(id: "TR", name: "Turkey", latitude: 39.9334, longitude: 32.8597),

        // Africa
        Country(id: "ZA", name: "South Africa", latitude: -25.7479, longitude: 28.2293),
        Country(id: "EG", name: "Egypt", latitude: 30.0444, longitude: 31.2357),
        Country(id: "NG", name: "Nigeria", latitude: 9.0765, longitude: 7.3986),
        Country(id: "KE", name: "Kenya", latitude: -1.2864, longitude: 36.8172),
        Country(id: "GH", name: "Ghana", latitude: 5.6037, longitude: -0.1870),
        Country(id: "MA", name: "Morocco", latitude: 34.0209, longitude: -6.8416),

        // Oceania
        Country(id: "AU", name: "Australia", latitude: -35.2809, longitude: 149.1300),
        Country(id: "NZ", name: "New Zealand", latitude: -41.2865, longitude: 174.7762),

        // Eastern Europe & Russia
        Country(id: "RU", name: "Russia", latitude: 55.7558, longitude: 37.6173),
        Country(id: "UA", name: "Ukraine", latitude: 50.4501, longitude: 30.5234),
        Country(id: "RO", name: "Romania", latitude: 44.4268, longitude: 26.1025),
        Country(id: "HU", name: "Hungary", latitude: 47.4979, longitude: 19.0402),
    ]

    // Get country by ID
    func getCountry(byId id: String) -> Country? {
        allCountries.first { $0.id == id }
    }

    // Sort countries alphabetically
    var sortedCountries: [Country] {
        allCountries.sorted { $0.name < $1.name }
    }
}
