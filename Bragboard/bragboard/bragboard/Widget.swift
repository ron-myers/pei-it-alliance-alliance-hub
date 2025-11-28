//
//  Widget.swift
//  bragboard
//
//  Core data models for widget system
//  ✨ UPDATED: hiringBadge now implemented
//

import Foundation
import SwiftData

// MARK: - Widget Model
@Model
final class Widget {
    // CloudKit requires default values on ALL non-optional properties
    var id: UUID = UUID()
    
    // Store as String for CloudKit compatibility, use computed property for type
    var typeRawValue: String = "companyLogo"
    
    var isEnabled: Bool = true
    var position: Int = 0
    var lastUpdated: Date = Date()
    var configuration: WidgetConfiguration?
    
    // Computed property to work with WidgetType enum
    var type: WidgetType {
        get { WidgetType(rawValue: typeRawValue) ?? .companyLogo }
        set { typeRawValue = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), type: WidgetType = .companyLogo, isEnabled: Bool = true, position: Int = 0) {
        self.id = id
        self.typeRawValue = type.rawValue
        self.isEnabled = isEnabled
        self.position = position
        self.lastUpdated = Date()
    }
}

// MARK: - Widget Configuration
@Model
final class WidgetConfiguration {
    var widget: Widget?
    
    // Image-based widgets (logo, achievements, certifications)
    var imageData: Data?
    
    // API-based widgets
    var apiKey: String?
    var apiEndpoint: String?
    var refreshInterval: TimeInterval = 3600  // Default 1 hour
    
    // Counter widgets
    var counterValue: Int = 0
    var counterLabel: String = ""
    var startDate: Date?
    
    // Incident tracking
    var incidentDate: Date?
    var incidentLabel: String = "Last Incident"
    
    // Text widgets
    var textContent: String = ""
    var textItems: [String] = []  // For rotating text
    
    // Display preferences
    var displayFormat: String = "compact"  // "compact" or "detailed"
    var colorTheme: String = "default"
    
    // Geographic data
    var locationNames: [String] = []
    var locationCount: Int = 0
    
    init() {}
}

// MARK: - Widget Type Enum
enum WidgetType: String, Codable, CaseIterable {
    // ========== IMPLEMENTED WIDGETS ==========
    
    // Image-based
    case companyLogo = "companyLogo"
    
    // Stats/Counters - Manual Entry
    case customerCount = "customerCount"
    
    // Social Media - Mock Data (API not ready)
    case instagramFollowers = "instagramFollowers"
    
    // Geographic - Mock Data
    case locationsMap = "locationsMap"
    
    // Milestones
    case yearsInBusiness = "yearsInBusiness"              // Auto-calculate from founding date
    case daysSinceIncident = "daysSinceIncident"          // Safety counter
    
    // Team - ✨ NOW IMPLEMENTED
    case hiringBadge = "hiringBadge"                      // "We're Hiring!" badge
    
    // ========== TODO: FUTURE WIDGETS ==========
    
    // Social Media (pending API approval)
    case youtubeSubscribers = "youtubeSubscribers"        // TODO: YouTube API integration
    case linkedInFollowers = "linkedInFollowers"          // TODO: LinkedIn API integration
    case twitterFollowers = "twitterFollowers"            // TODO: Twitter API integration
    case tiktokFollowers = "tiktokFollowers"              // TODO: TikTok API integration
    
    // Reviews (pending API approval)
    case googleReviews = "googleReviews"                  // TODO: Google Places API
    case yelpRating = "yelpRating"                        // TODO: Yelp Fusion API
    case appStoreRating = "appStoreRating"                // TODO: App Store Connect API
    case aggregateRating = "aggregateRating"              // TODO: Combined rating display
    
    // Milestones
    case customCounter = "customCounter"                  // TODO: Generic real-time counter
    
    // Achievements
    case achievements = "achievements"                     // TODO: Image upload for awards
    case certifications = "certifications"                 // TODO: ISO badges, etc.
    case featuredInMedia = "featuredInMedia"              // TODO: Media logo display
    
    // Text-based
    case testimonial = "testimonial"                       // TODO: Rotating testimonials
    case tagline = "tagline"                              // TODO: Mission statement
    case announcement = "announcement"                     // TODO: Current promotion
    
    // Geographic
    case countriesServed = "countriesServed"              // TODO: Country counter
    
    // Team
    case teamSize = "teamSize"                            // TODO: Team member count
    
    var displayName: String {
        switch self {
        // Implemented
        case .companyLogo: return "Company Logo"
        case .customerCount: return "Customer Counter"
        case .instagramFollowers: return "Instagram Followers"
        case .locationsMap: return "Location Map"
        case .yearsInBusiness: return "Years in Business"
        case .daysSinceIncident: return "Days Since Incident"
        case .hiringBadge: return "We're Hiring"
            
        // TODO
        case .youtubeSubscribers: return "YouTube Subscribers"
        case .linkedInFollowers: return "LinkedIn Followers"
        case .twitterFollowers: return "Twitter/X Followers"
        case .tiktokFollowers: return "TikTok Followers"
        case .googleReviews: return "Google Reviews"
        case .yelpRating: return "Yelp Rating"
        case .appStoreRating: return "App Store Rating"
        case .aggregateRating: return "Aggregate Rating"
        case .customCounter: return "Custom Counter"
        case .achievements: return "Awards & Achievements"
        case .certifications: return "Certifications"
        case .featuredInMedia: return "Featured In"
        case .testimonial: return "Customer Testimonials"
        case .tagline: return "Company Tagline"
        case .announcement: return "Announcement"
        case .countriesServed: return "Countries Served"
        case .teamSize: return "Team Size"
        }
    }
    
    var icon: String {
        switch self {
        // Implemented
        case .companyLogo: return "building.2"
        case .customerCount: return "person.3"
        case .instagramFollowers: return "camera"
        case .locationsMap: return "map"
        case .yearsInBusiness: return "calendar"
        case .daysSinceIncident: return "checkmark.shield"
        case .hiringBadge: return "person.badge.plus"
            
        // TODO
        case .youtubeSubscribers: return "play.rectangle"
        case .linkedInFollowers: return "briefcase"
        case .twitterFollowers: return "bird"
        case .tiktokFollowers: return "music.note"
        case .googleReviews: return "star.fill"
        case .yelpRating: return "star.circle"
        case .appStoreRating: return "apps.iphone"
        case .aggregateRating: return "star.leadinghalf.filled"
        case .customCounter: return "number"
        case .achievements: return "trophy"
        case .certifications: return "seal"
        case .featuredInMedia: return "newspaper"
        case .testimonial: return "quote.bubble"
        case .tagline: return "text.quote"
        case .announcement: return "megaphone"
        case .countriesServed: return "globe"
        case .teamSize: return "person.2"
        }
    }
    
    var category: WidgetCategory {
        switch self {
        case .companyLogo: return .branding
        case .customerCount: return .metrics
        case .instagramFollowers, .youtubeSubscribers, .linkedInFollowers,
             .twitterFollowers, .tiktokFollowers: return .social
        case .googleReviews, .yelpRating, .appStoreRating, .aggregateRating: return .reviews
        case .yearsInBusiness, .daysSinceIncident, .customCounter: return .milestones
        case .achievements, .certifications, .featuredInMedia: return .achievements
        case .testimonial, .tagline, .announcement: return .text
        case .locationsMap, .countriesServed: return .geographic
        case .teamSize, .hiringBadge: return .team
        }
    }
    
    var isImplemented: Bool {
        switch self {
        case .companyLogo, .customerCount, .instagramFollowers, .locationsMap,
             .yearsInBusiness, .daysSinceIncident, .hiringBadge:
            return true
        default:
            return false
        }
    }
}

// MARK: - Widget Category
enum WidgetCategory: String, CaseIterable {
    case branding = "Branding"
    case metrics = "Metrics"
    case social = "Social Media"
    case reviews = "Reviews & Ratings"
    case milestones = "Milestones"
    case achievements = "Achievements"
    case text = "Text & Messages"
    case geographic = "Geographic"
    case team = "Team"
}

