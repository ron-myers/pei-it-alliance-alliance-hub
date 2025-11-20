//
//  MockDataService.swift
//  bragboard
//
//  Provides sample/mock data for widgets during development
//  Replace with real API calls when approved
//

import Foundation

class MockDataService {
    static let shared = MockDataService()
    
    private init() {}
    
    // MARK: - Mock Social Media Data
    
    func getInstagramFollowers() -> Int {
        // Mock data - simulates growing follower count
        let baseFollowers = 12_567
        let randomGrowth = Int.random(in: 0...100)
        return baseFollowers + randomGrowth
    }
    
    // TODO: Implement when YouTube API is approved
    func getYouTubeSubscribers() async throws -> Int {
        throw MockDataError.notImplemented("YouTube API integration pending")
    }
    
    // TODO: Implement when LinkedIn API is approved
    func getLinkedInFollowers() async throws -> Int {
        throw MockDataError.notImplemented("LinkedIn API integration pending")
    }
    
    // TODO: Implement when Twitter API is approved
    func getTwitterFollowers() async throws -> Int {
        throw MockDataError.notImplemented("Twitter API integration pending")
    }
    
    // TODO: Implement when TikTok API is approved
    func getTikTokFollowers() async throws -> Int {
        throw MockDataError.notImplemented("TikTok API integration pending")
    }
    
    // MARK: - Mock Geographic Data
    
    func getLocationNames() -> [String] {
        // Mock data - sample office locations
        return [
            "New York, USA",
            "London, UK",
            "Singapore",
            "Sydney, Australia",
            "Toronto, Canada"
        ]
    }
    
    func getLocationCount() -> Int {
        return getLocationNames().count
    }
    
    // TODO: Implement when ready
    func getCountriesServed() -> Int {
        return 23  // Mock number
    }
    
    // MARK: - Mock Review Data
    
    // TODO: Implement when Google Places API is approved
    func getGoogleReviews() async throws -> (rating: Double, count: Int) {
        throw MockDataError.notImplemented("Google Places API integration pending")
    }
    
    // TODO: Implement when Yelp API is approved
    func getYelpRating() async throws -> (rating: Double, count: Int) {
        throw MockDataError.notImplemented("Yelp Fusion API integration pending")
    }
    
    // TODO: Implement when App Store Connect API is available
    func getAppStoreRating() async throws -> (rating: Double, count: Int) {
        throw MockDataError.notImplemented("App Store Connect API integration pending")
    }
    
    // MARK: - Mock Milestone Data
    
    // TODO: Implement auto-calculation from founding date
    func getYearsInBusiness(foundingDate: Date) -> Int {
        let calendar = Calendar.current
        let years = calendar.dateComponents([.year], from: foundingDate, to: Date()).year ?? 0
        return years
    }
    
    // TODO: Implement safety counter
    func getDaysSinceIncident(lastIncidentDate: Date) -> Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: lastIncidentDate, to: Date()).day ?? 0
        return days
    }
    
    // MARK: - Helper Methods
    
    /// Formats large numbers into readable format (e.g., 12.5K, 1.2M)
    static func formatNumber(_ value: Int, style: NumberFormatStyle = .compact) -> String {
        switch style {
        case .compact:
            if value >= 1_000_000 {
                let millions = Double(value) / 1_000_000.0
                return String(format: "%.1fM", millions)
            } else if value >= 1_000 {
                let thousands = Double(value) / 1_000.0
                return String(format: "%.1fK", thousands)
            } else {
                return "\(value)"
            }
            
        case .full:
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        }
    }
    
    enum NumberFormatStyle {
        case compact  // 12.5K, 1.2M
        case full     // 12,500, 1,234,567
    }
}

enum MockDataError: LocalizedError {
    case notImplemented(String)
    
    var errorDescription: String? {
        switch self {
        case .notImplemented(let message):
            return message
        }
    }
}
