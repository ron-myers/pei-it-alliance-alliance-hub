//
//  LocariusEventService.swift
//  bragboard
//
//  Service for fetching events from Locarius API
//

import Foundation

// MARK: - Event Models
struct LocariusEvent: Codable, Identifiable {
    var id: String { url }
    let name: String
    let description: EventDescription
    let url: String
    let start: EventStart
    let capacity: Int
    let is_free: Bool
    let summary: String
    let logo: String?
    
    struct EventDescription: Codable {
        let text: String
        let html: String
    }
    
    struct EventStart: Codable {
        let timezone: String
        let local: String
        let utc: String
    }
    
    // Computed properties
    var isNightShift: Bool {
        name.lowercased().contains("night shift")
    }
    
    var startDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: start.utc)
    }
    
    var formattedDate: String {
        guard let date = startDate else { return start.local }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var displayDate: String {
        // Parse the local string format: "Thursday, December 11, 2025 at 06:00 PM"
        let components = start.local.components(separatedBy: " at ")
        if components.count == 2 {
            let datePart = components[0]
            let timePart = components[1]
            
            // Extract month and day (skip day of week)
            let dateComponents = datePart.components(separatedBy: ", ")
            if dateComponents.count >= 2 {
                // dateComponents[0] is day of week (Thursday)
                // dateComponents[1] is month and day (December 11)
                let monthDay = dateComponents[1]
                
                // Shorten month name: "December 11" -> "Dec 11"
                let monthDayParts = monthDay.components(separatedBy: " ")
                if monthDayParts.count >= 2 {
                    let fullMonth = monthDayParts[0]
                    let day = monthDayParts[1]
                    
                    // Get abbreviated month
                    let monthAbbrev: String
                    switch fullMonth {
                    case "January": monthAbbrev = "Jan"
                    case "February": monthAbbrev = "Feb"
                    case "March": monthAbbrev = "Mar"
                    case "April": monthAbbrev = "Apr"
                    case "May": monthAbbrev = "May"
                    case "June": monthAbbrev = "Jun"
                    case "July": monthAbbrev = "Jul"
                    case "August": monthAbbrev = "Aug"
                    case "September": monthAbbrev = "Sep"
                    case "October": monthAbbrev = "Oct"
                    case "November": monthAbbrev = "Nov"
                    case "December": monthAbbrev = "Dec"
                    default: monthAbbrev = fullMonth
                    }
                    
                    return "\(monthAbbrev) \(day), \(timePart)"
                }
            }
        }
        return start.local
    }
}

struct LocariusResponse: Codable {
    let body: LocariusBody
    let message: String
    let version: String
    
    struct LocariusBody: Codable {
        let result: [LocariusEvent]
    }
}

// MARK: - Service
class LocariusEventService {
    static let shared = LocariusEventService()
    
    private init() {}
    
    /// Fetches upcoming events from the Locarius API
    /// - Parameter token: API token (loaded from secure config)
    /// - Returns: Array of upcoming events
    func fetchUpcomingEvents(token: String) async throws -> [LocariusEvent] {
        print("API: Starting fetch...")
        
        guard !token.isEmpty else {
            print("API: Token is empty")
            throw LocariusError.missingToken
        }
        
        print("API: Token present (length: \(token.count))")
        
        let urlString = "https://api.prod.locarius.io/v1/data/18335/events?token=\(token)"
        print("API: Making request to Locarius...")
        
        guard let url = URL(string: urlString) else {
            print("API: Invalid URL")
            throw LocariusError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            print("API: Got response, size: \(data.count) bytes")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("API: Invalid HTTP response")
                throw LocariusError.invalidResponse
            }
            
            print("API: HTTP Status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("API: HTTP error \(httpResponse.statusCode)")
                throw LocariusError.httpError(statusCode: httpResponse.statusCode)
            }
            
            print("API: Decoding JSON...")
            
            let decoder = JSONDecoder()
            let locariusResponse = try decoder.decode(LocariusResponse.self, from: data)
            
            let events = locariusResponse.body.result
            print("API: Successfully decoded \(events.count) events")
            
            // Log event names
            for (index, event) in events.prefix(5).enumerated() {
                print("  Event \(index + 1): \(event.name)")
            }
            
            return events
            
        } catch let error as DecodingError {
            print("API: JSON decode error: \(error)")
            throw error
        } catch let error as URLError {
            print("API: Network error: \(error.localizedDescription)")
            print("  Code: \(error.code.rawValue)")
            throw error
        } catch {
            print("API: Unknown error: \(error)")
            throw error
        }
    }
    
    /// Gets the next event based on priority logic:
    /// 1. Next non-Night Shift event if available
    /// 2. Otherwise, next Night Shift event
    func getNextEvent(from events: [LocariusEvent]) -> LocariusEvent? {
        print("API: Finding next event from \(events.count) total events")
        
        let now = Date()
        print("API: Current time: \(now)")
        
        // Debug: Check date parsing for each event
        print("API: Debugging date parsing:")
        for (index, event) in events.enumerated() {
            print("  Event \(index + 1): \(event.name)")
            print("    UTC: \(event.start.utc)")
            if let date = event.startDate {
                print("    Parsed: \(date)")
                print("    Future? \(date > now)")
            } else {
                print("    ERROR: Failed to parse date!")
            }
        }
        
        // Filter to only future events
        let upcomingEvents = events.filter { event in
            guard let eventDate = event.startDate else {
                print("API: Event \(event.name) has no valid date")
                return false
            }
            let isFuture = eventDate > now
            return isFuture
        }.sorted { event1, event2 in
            guard let date1 = event1.startDate, let date2 = event2.startDate else { return false }
            return date1 < date2
        }
        
        print("API: Found \(upcomingEvents.count) upcoming events")
        
        // Log all upcoming events
        for (index, event) in upcomingEvents.prefix(5).enumerated() {
            let isNS = event.isNightShift ? " [Night Shift]" : ""
            print("  \(index + 1). \(event.name)\(isNS) - \(event.displayDate)")
        }
        
        // First, try to find a non-Night Shift event
        if let nextNonNightShift = upcomingEvents.first(where: { !$0.isNightShift }) {
            print("API: Selected: \(nextNonNightShift.name) (Non-Night Shift)")
            return nextNonNightShift
        }
        
        // If no non-Night Shift events, return the next Night Shift
        if let nextNightShift = upcomingEvents.first(where: { $0.isNightShift }) {
            print("API: Selected: \(nextNightShift.name) (Night Shift fallback)")
            return nextNightShift
        }
        
        print("API: No upcoming events found")
        return nil
    }
}

// MARK: - Errors
enum LocariusError: LocalizedError {
    case missingToken
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "API token not configured"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        }
    }
}
