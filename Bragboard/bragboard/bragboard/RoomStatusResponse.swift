//
//  RoomStatusService.swift
//  bragboard
//
//  Service for fetching and managing room status data from The Foundry Room Hub API
//

import Foundation

// MARK: - Base44 API Models (Alternative data source)
struct Base44Room: Codable {
    let id: String
    let name: String
    let roomNumber: String
    let floor: String
    let capacity: Int
    let amenities: [String]?
    let description: String?
    let isActive: Bool
    let maxBookingDuration: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, floor, capacity, amenities, description
        case roomNumber = "room_number"
        case isActive = "is_active"
        case maxBookingDuration = "max_booking_duration"
    }
}

struct Base44Booking: Codable {
    let id: String
    let roomId: String
    let title: String
    let description: String?
    let startTime: String
    let endTime: String
    let status: String
    let attendees: [String]?
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, status, attendees, notes
        case roomId = "room_id"
        case startTime = "start_time"
        case endTime = "end_time"
    }
    
    var startDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: startTime)
    }
    
    var endDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: endTime)
    }
    
    // Check if this booking is currently active
    func isCurrentlyActive(at currentTime: Date = Date()) -> Bool {
        guard let start = startDate, let end = endDate else {
            print("⚠️ Could not parse dates for booking: \(id)")
            return false
        }
        
        let isActive = currentTime >= start && currentTime <= end
        
        // Debug logging
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        
        print("🔍 Booking '\(title)' (ID: \(id.prefix(8))...)")
        print("   Start: \(formatter.string(from: start))")
        print("   End: \(formatter.string(from: end))")
        print("   Now: \(formatter.string(from: currentTime))")
        print("   Status: \(isActive ? "✅ ACTIVE" : "⏸️ NOT ACTIVE")")
        
        return isActive
    }
    
    // Check if this booking is in the future
    func isFuture(from currentTime: Date = Date()) -> Bool {
        guard let start = startDate else { return false }
        return start > currentTime
    }
}

// MARK: - Room Status Models
struct RoomStatusResponse: Codable {
    let timestamp: String
    let roomCount: Int
    let availableCount: Int
    let occupiedCount: Int
    let rooms: [RoomInfo]
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case roomCount = "room_count"
        case availableCount = "available_count"
        case occupiedCount = "occupied_count"
        case rooms
    }
}

struct RoomInfo: Codable, Identifiable {
    let id: String
    let name: String
    let roomNumber: String
    let floor: String
    let capacity: Int
    let status: RoomStatus
    let currentBooking: BookingInfo?
    let nextBooking: BookingInfo?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case roomNumber = "room_number"
        case floor, capacity, status
        case currentBooking = "current_booking"
        case nextBooking = "next_booking"
    }
}

enum RoomStatus: String, Codable {
    case available = "available"
    case occupied = "occupied"
    case maintenance = "maintenance"
    
    var displayName: String {
        switch self {
        case .available: return "Available"
        case .occupied: return "Occupied"
        case .maintenance: return "Maintenance"
        }
    }
    
    var colorName: String {
        switch self {
        case .available: return "green"
        case .occupied: return "red"
        case .maintenance: return "orange"
        }
    }
}

struct BookingInfo: Codable {
    let id: String
    let title: String
    let startTime: String
    let endTime: String
    
    enum CodingKeys: String, CodingKey {
        case id, title
        case startTime = "start_time"
        case endTime = "end_time"
    }
    
    var startDate: Date? {
        ISO8601DateFormatter().date(from: startTime)
    }
    
    var endDate: Date? {
        ISO8601DateFormatter().date(from: endTime)
    }
}

// MARK: - Display Options (for user configuration)
struct RoomDisplayOptions: Codable {
    var showRoomNumber: Bool = false
    var showFloor: Bool = false
    var showCapacity: Bool = false
    var showCurrentBooking: Bool = false
    var showNextBooking: Bool = false
    
    // Determine if widget needs 2x size
    var needsExpandedSize: Bool {
        showRoomNumber || showFloor || showCapacity || showCurrentBooking || showNextBooking
    }
}

// MARK: - Room Status Service
class RoomStatusService {
    static let shared = RoomStatusService()
    
    // Base44 API endpoints
    private let base44RoomsEndpoint = "https://base44.app/api/apps/689cceadf2c7408b283ab894/entities/Room?q=%7B%22is_active%22:true%7D"
    private let base44BookingsEndpoint = "https://base44.app/api/apps/689cceadf2c7408b283ab894/entities/Booking?q=%7B%22status%22:%22confirmed%22%7D"
    
    // Multiple endpoint options to try
    // Priority 1: Base44 API - Returns clean JSON with booking data
    // Priority 2+: Room Hub endpoints - May return HTML or full booking data
    private let endpointOptions = [
        "https://thefoundryroomhub.ca/RoomStatusAPI",
        "https://thefoundryroomhub.ca/api/RoomStatusAPI",
        "https://thefoundryroomhub.ca/api/rooms",
        "https://thefoundryroomhub.ca/api/v1/rooms"
    ]
    
    private init() {}
    
    /// Fetch current room status from API with automatic endpoint fallback
    func fetchRoomStatus() async throws -> RoomStatusResponse {
        var lastError: Error?
        
        // Strategy 1: Try Base44 API with rooms + bookings (best option)
        do {
            print("🔗 Attempting Base44 API (rooms + bookings)...")
            return try await fetchBase44RoomStatus()
        } catch {
            print("❌ Base44 API failed: \(error.localizedDescription)")
            lastError = error
        }
        
        // Strategy 2: Try each Room Hub endpoint until one works
        for endpoint in endpointOptions {
            do {
                print("🔗 Attempting: \(endpoint)")
                return try await fetchFromEndpoint(endpoint)
            } catch {
                print("❌ Failed: \(endpoint) - \(error.localizedDescription)")
                lastError = error
                continue
            }
        }
        
        // If all endpoints failed, throw the last error
        throw lastError ?? RoomStatusError.allEndpointsFailed
    }
    
    /// Fetch and combine room + booking data from Base44 API
    private func fetchBase44RoomStatus() async throws -> RoomStatusResponse {
        // Fetch rooms and bookings concurrently
        async let roomsData = fetchBase44Rooms()
        async let bookingsData = fetchBase44Bookings()
        
        let (rooms, bookings) = try await (roomsData, bookingsData)
        
        print("✅ Fetched \(rooms.count) rooms and \(bookings.count) bookings from Base44")
        
        // Filter bookings to only current and future ones
        let relevantBookings = filterRelevantBookings(bookings)
        print("📅 Filtered to \(relevantBookings.count) current/future bookings")
        
        // Combine rooms with booking data
        return combineRoomsWithBookings(rooms: rooms, bookings: relevantBookings)
    }
    
    /// Fetch rooms from Base44
    private func fetchBase44Rooms() async throws -> [Base44Room] {
        guard let url = URL(string: base44RoomsEndpoint) else {
            throw RoomStatusError.invalidURL
        }
        
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.timeoutIntervalForRequest = 15
        
        let session = URLSession(configuration: config)
        let (data, _) = try await session.data(from: url)
        
        let decoder = JSONDecoder()
        return try decoder.decode([Base44Room].self, from: data)
    }
    
    /// Fetch bookings from Base44
    private func fetchBase44Bookings() async throws -> [Base44Booking] {
        guard let url = URL(string: base44BookingsEndpoint) else {
            throw RoomStatusError.invalidURL
        }
        
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.timeoutIntervalForRequest = 15
        
        let session = URLSession(configuration: config)
        let (data, _) = try await session.data(from: url)
        
        let decoder = JSONDecoder()
        return try decoder.decode([Base44Booking].self, from: data)
    }
    
    /// Filter bookings to only keep current and near-future ones
    private func filterRelevantBookings(_ bookings: [Base44Booking]) -> [Base44Booking] {
        let now = Date()
        let twentyFourHoursLater = now.addingTimeInterval(24 * 60 * 60)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .short
        timeFormatter.timeStyle = .short
        
        print("\n🔍 Filtering Bookings:")
        print("   Current time: \(timeFormatter.string(from: now))")
        print("   24h cutoff: \(timeFormatter.string(from: twentyFourHoursLater))")
        print("   Total bookings to filter: \(bookings.count)\n")
        
        let filtered = bookings.filter { booking in
            guard let startDate = booking.startDate, let endDate = booking.endDate else {
                print("   ❌ Skipped (invalid dates): \(booking.title)")
                return false
            }
            
            // Keep if:
            // 1. End time is in the future (includes currently active bookings)
            // 2. Starts within the next 24 hours
            let endInFuture = endDate > now
            let startsWithin24h = startDate < twentyFourHoursLater
            let shouldKeep = endInFuture && startsWithin24h
            
            let status = shouldKeep ? "✅ KEEP" : "❌ DROP"
            print("   \(status): '\(booking.title)'")
            print("      Start: \(timeFormatter.string(from: startDate))")
            print("      End: \(timeFormatter.string(from: endDate))")
            
            if !endInFuture {
                print("      Reason: Already ended")
            } else if !startsWithin24h {
                print("      Reason: Starts more than 24h in future")
            }
            print("")
            
            return shouldKeep
        }
        
        print("📊 Filtering result: Kept \(filtered.count) of \(bookings.count) bookings\n")
        return filtered
    }
    
    /// Combine room data with booking data to create RoomStatusResponse
    private func combineRoomsWithBookings(rooms: [Base44Room], bookings: [Base44Booking]) -> RoomStatusResponse {
        let now = Date()
        
        // Log current time in local timezone
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .medium
        timeFormatter.timeStyle = .long
        timeFormatter.timeZone = TimeZone.current
        
        print("\n⏰ Current Time Analysis:")
        print("   Local Time: \(timeFormatter.string(from: now))")
        print("   Timezone: \(TimeZone.current.identifier) (UTC\(TimeZone.current.secondsFromGMT() / 3600))")
        print("   Processing \(bookings.count) bookings for \(rooms.count) rooms\n")
        
        var availableCount = 0
        var occupiedCount = 0
        
        let roomInfos = rooms.map { room -> RoomInfo in
            print("🏢 Processing room: \(room.name) (ID: \(room.id))")
            
            // Find bookings for this room
            let roomBookings = bookings.filter { $0.roomId == room.id }
            print("   Found \(roomBookings.count) booking(s) for this room")
            
            // Find current booking (if any)
            let currentBooking = roomBookings.first { booking in
                guard let start = booking.startDate, let end = booking.endDate else {
                    print("   ⚠️ Skipping booking with invalid dates: \(booking.id)")
                    return false
                }
                let isActive = now >= start && now <= end
                
                if isActive {
                    print("   ✅ CURRENT BOOKING FOUND: '\(booking.title)'")
                    print("      Ends at: \(timeFormatter.string(from: end))")
                }
                
                return isActive
            }
            
            // Find next booking (earliest future booking)
            let futureBookings = roomBookings.filter { booking in
                guard let start = booking.startDate else { return false }
                return start > now
            }.sorted { booking1, booking2 in
                guard let start1 = booking1.startDate, let start2 = booking2.startDate else { return false }
                return start1 < start2
            }
            let nextBooking = futureBookings.first
            
            if let next = nextBooking, let nextStart = next.startDate {
                print("   📅 Next booking: '\(next.title)' at \(timeFormatter.string(from: nextStart))")
            } else {
                print("   📅 No upcoming bookings")
            }
            
            // Determine status
            let status: RoomStatus = currentBooking != nil ? .occupied : .available
            
            if status == .available {
                availableCount += 1
                print("   🟢 Status: AVAILABLE\n")
            } else {
                occupiedCount += 1
                print("   🔴 Status: OCCUPIED\n")
            }
            
            // Convert Base44 bookings to RoomInfo format
            let currentBookingInfo = currentBooking.map { booking in
                BookingInfo(
                    id: booking.id,
                    title: booking.title,
                    startTime: booking.startTime,
                    endTime: booking.endTime
                )
            }
            
            let nextBookingInfo = nextBooking.map { booking in
                BookingInfo(
                    id: booking.id,
                    title: booking.title,
                    startTime: booking.startTime,
                    endTime: booking.endTime
                )
            }
            
            return RoomInfo(
                id: room.id,
                name: room.name,
                roomNumber: room.roomNumber,
                floor: room.floor,
                capacity: room.capacity,
                status: status,
                currentBooking: currentBookingInfo,
                nextBooking: nextBookingInfo
            )
        }
        
        print("📊 Final Summary:")
        print("   Total Rooms: \(roomInfos.count)")
        print("   Available: \(availableCount)")
        print("   Occupied: \(occupiedCount)\n")
        
        return RoomStatusResponse(
            timestamp: ISO8601DateFormatter().string(from: now),
            roomCount: roomInfos.count,
            availableCount: availableCount,
            occupiedCount: occupiedCount,
            rooms: roomInfos
        )
    }
    
    /// Fetch from a specific endpoint
    private func fetchFromEndpoint(_ urlString: String) async throws -> RoomStatusResponse {
        guard let url = URL(string: urlString) else {
            throw RoomStatusError.invalidURL
        }
        
        // Create URLSession with custom configuration
        let config = URLSessionConfiguration.default
        
        // Disable caching to ensure fresh data
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        
        // Set timeout
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        
        // More aggressive browser headers
        config.httpAdditionalHeaders = [
            "Accept": "application/json, text/plain, */*",
            "Accept-Language": "en-US,en;q=0.9",
            "Accept-Encoding": "gzip, deflate, br",
            "DNT": "1",
            "Sec-Fetch-Dest": "empty",
            "Sec-Fetch-Mode": "cors",
            "Sec-Fetch-Site": "same-origin",
            "Cache-Control": "no-cache",
            "Pragma": "no-cache"
        ]
        
        let session = URLSession(configuration: config)
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Critical: Most realistic User-Agent for mobile Safari
        // This matches what a real iPhone would send
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        // Additional headers that a real browser would send
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("https://thefoundryroomhub.ca", forHTTPHeaderField: "Origin")
        request.setValue("https://thefoundryroomhub.ca", forHTTPHeaderField: "Referer")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RoomStatusError.invalidResponse
        }
        
        print("📡 HTTP Status: \(httpResponse.statusCode)")
        print("📋 Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
        
        guard httpResponse.statusCode == 200 else {
            throw RoomStatusError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        
        // First, try to decode as direct JSON (standard RoomStatusResponse format)
        do {
            let roomStatus = try decoder.decode(RoomStatusResponse.self, from: data)
            print("✅ Successfully decoded \(roomStatus.roomCount) rooms from \(urlString)")
            return roomStatus
        } catch {
            // Try Base44 format (array of rooms)
            if let base44Rooms = try? decoder.decode([Base44Room].self, from: data) {
                print("✅ Decoded Base44 format with \(base44Rooms.count) rooms")
                return convertBase44ToRoomStatus(base44Rooms)
            }
            
            // If direct JSON fails, check if it's HTML with embedded JSON
            if let responseString = String(data: data, encoding: .utf8),
               responseString.trimmingCharacters(in: .whitespaces).starts(with: "<") {
                print("🔍 Received HTML - attempting to extract embedded JSON...")
                
                // Save HTML to temp file for inspection
                saveHTMLForInspection(responseString, from: urlString)
                
                // Try to extract JSON from HTML
                if let extractedJSON = extractJSONFromHTML(responseString) {
                    print("✅ Successfully extracted JSON from HTML!")
                    return extractedJSON
                } else {
                    print("❌ Could not find JSON data in HTML")
                    print("📄 HTML Response preview: \(responseString.prefix(500))...")
                    throw RoomStatusError.htmlResponse
                }
            }
            
            // Neither JSON nor parseable HTML
            print("❌ JSON Decoding Error: \(error)")
            if let dataString = String(data: data, encoding: .utf8) {
                print("📄 Response preview: \(dataString.prefix(500))...")
            }
            throw RoomStatusError.decodingError(error.localizedDescription)
        }
    }
    
    /// Convert Base44 room array to RoomStatusResponse format
    private func convertBase44ToRoomStatus(_ base44Rooms: [Base44Room]) -> RoomStatusResponse {
        let rooms = base44Rooms.map { room in
            RoomInfo(
                id: room.id,
                name: room.name,
                roomNumber: room.roomNumber,
                floor: room.floor,
                capacity: room.capacity,
                status: .available,  // Base44 doesn't provide real-time status
                currentBooking: nil,
                nextBooking: nil
            )
        }
        
        return RoomStatusResponse(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            roomCount: rooms.count,
            availableCount: rooms.count,  // Assume all available since we don't have booking data
            occupiedCount: 0,
            rooms: rooms
        )
    }
    
    /// Save HTML response to a temporary file for manual inspection
    private func saveHTMLForInspection(_ html: String, from url: String) {
        let fileName = "room_status_response_\(Date().timeIntervalSince1970).html"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try html.write(to: fileURL, atomically: true, encoding: .utf8)
            print("💾 Saved HTML to: \(fileURL.path)")
            print("   You can inspect this file to see what the server is returning")
        } catch {
            print("⚠️ Could not save HTML file: \(error)")
        }
    }
    
    /// Extract JSON data embedded in HTML (common in SSR apps like Next.js)
    private func extractJSONFromHTML(_ html: String) -> RoomStatusResponse? {
        print("🔍 Starting comprehensive HTML parsing...")
        print("📄 HTML Length: \(html.count) characters")
        
        // Strategy 1: Look for __NEXT_DATA__ or similar embedded JSON (most common)
        if let jsonData = extractEmbeddedJSON(from: html) {
            return jsonData
        }
        
        // Strategy 2: Look for JSON in script tags without specific IDs
        if let jsonData = extractScriptJSON(from: html) {
            return jsonData
        }
        
        // Strategy 3: Aggressive search - find any valid JSON containing room_count
        if let jsonData = extractAnyValidJSON(from: html) {
            return jsonData
        }
        
        // Strategy 4: Last resort - scrape the visible HTML structure
        print("⚠️ No embedded JSON found, attempting to scrape HTML structure...")
        if let jsonData = scrapeHTMLStructure(from: html) {
            return jsonData
        }
        
        print("❌ All parsing strategies failed")
        return nil
    }
    
    /// Strategy 1: Extract from common embedded JSON patterns
    private func extractEmbeddedJSON(from html: String) -> RoomStatusResponse? {
        let patterns = [
            #"<script id="__NEXT_DATA__"[^>]*>(.*?)</script>"#,
            #"<script type="application/json"[^>]*>(.*?)</script>"#,
            #"window\.__INITIAL_STATE__\s*=\s*(\{.*?\});?"#,
            #"window\.roomStatus\s*=\s*(\{.*?\});?"#,
            #"self\.__next_f\.push\(\[.*?"props":(\{.*?\})\]"#,
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               match.numberOfRanges > 1 {
                
                let jsonRange = match.range(at: 1)
                if let swiftRange = Range(jsonRange, in: html) {
                    var jsonString = String(html[swiftRange])
                    
                    // Clean up escaped JSON if needed
                    jsonString = jsonString.replacingOccurrences(of: "\\\"", with: "\"")
                    jsonString = jsonString.replacingOccurrences(of: "\\/", with: "/")
                    
                    if let result = tryDecodeJSON(jsonString, source: "Embedded pattern: \(pattern)") {
                        return result
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Strategy 2: Extract JSON from any script tag
    private func extractScriptJSON(from html: String) -> RoomStatusResponse? {
        // Find all script tags
        let scriptPattern = #"<script[^>]*>(.*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: scriptPattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }
        
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        print("📜 Found \(matches.count) script tags")
        
        for match in matches {
            if match.numberOfRanges > 1,
               let swiftRange = Range(match.range(at: 1), in: html) {
                let scriptContent = String(html[swiftRange])
                
                // Skip if it's obviously JavaScript code, not JSON
                if scriptContent.contains("function") || scriptContent.contains("var ") || scriptContent.contains("const ") {
                    continue
                }
                
                // Try to find JSON objects in this script
                if let result = extractJSONFromString(scriptContent) {
                    return result
                }
            }
        }
        
        return nil
    }
    
    /// Strategy 3: Find ANY valid JSON containing room_count
    private func extractAnyValidJSON(from html: String) -> RoomStatusResponse? {
        // Look for room_count as an anchor point
        let roomCountPattern = "\"room_count\"\\s*:\\s*\\d+"
        guard let regex = try? NSRegularExpression(pattern: roomCountPattern, options: []) else {
            return nil
        }
        
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        print("🎯 Found \(matches.count) occurrences of room_count")
        
        for match in matches {
            let matchRange = match.range
            if let swiftRange = Range(matchRange, in: html) {
                // Extract surrounding JSON object
                if let jsonString = extractSurroundingJSON(from: html, around: swiftRange) {
                    if let result = tryDecodeJSON(jsonString, source: "Extracted around room_count") {
                        return result
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Strategy 4: Scrape visible HTML structure (last resort)
    private func scrapeHTMLStructure(from html: String) -> RoomStatusResponse? {
        print("🕷️ Attempting to scrape visible HTML elements...")
        
        // This would require parsing the actual DOM structure
        // For now, return nil and print debug info
        
        // Save a snippet for manual inspection
        let preview = html.prefix(2000)
        print("📄 HTML Preview for manual inspection:")
        print("=====================================")
        print(preview)
        print("=====================================")
        
        return nil
    }
    
    /// Helper: Extract surrounding JSON object
    private func extractSurroundingJSON(from html: String, around range: Range<String.Index>) -> String? {
        var startIndex = range.lowerBound
        var braceCount = 0
        var foundStart = false
        
        // Search backwards for opening brace
        while startIndex > html.startIndex {
            startIndex = html.index(before: startIndex)
            if html[startIndex] == "{" {
                foundStart = true
                braceCount = 1
                break
            }
        }
        
        guard foundStart else { return nil }
        
        var endIndex = range.upperBound
        
        // Search forwards matching braces
        while endIndex < html.endIndex && braceCount > 0 {
            if html[endIndex] == "{" {
                braceCount += 1
            } else if html[endIndex] == "}" {
                braceCount -= 1
            }
            endIndex = html.index(after: endIndex)
        }
        
        guard braceCount == 0 else { return nil }
        
        return String(html[startIndex..<endIndex])
    }
    
    /// Helper: Extract JSON from a string that might contain it
    private func extractJSONFromString(_ text: String) -> RoomStatusResponse? {
        // Look for JSON objects (starting with { and containing room_count)
        if text.contains("room_count") {
            // Try to extract the JSON object
            if let startIndex = text.firstIndex(of: "{") {
                let jsonCandidate = String(text[startIndex...])
                if let result = tryDecodeJSON(jsonCandidate, source: "Script content") {
                    return result
                }
            }
        }
        
        return nil
    }
    
    /// Helper: Try to decode JSON string
    private func tryDecodeJSON(_ jsonString: String, source: String) -> RoomStatusResponse? {
        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        
        // Try direct decode
        if let roomStatus = try? decoder.decode(RoomStatusResponse.self, from: jsonData) {
            print("✅ Decoded from \(source)")
            return roomStatus
        }
        
        // Try nested structures
        if let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            // Next.js patterns
            if let props = jsonObject["props"] as? [String: Any],
               let pageProps = props["pageProps"] as? [String: Any] {
                
                // Try various nested keys
                let possibleKeys = ["roomData", "roomStatus", "data", "initialData"]
                for key in possibleKeys {
                    if let roomData = pageProps[key] as? [String: Any],
                       let nestedData = try? JSONSerialization.data(withJSONObject: roomData),
                       let roomStatus = try? decoder.decode(RoomStatusResponse.self, from: nestedData) {
                        print("✅ Decoded from \(source) - nested key: \(key)")
                        return roomStatus
                    }
                }
            }
            
            // Try direct keys
            let possibleKeys = ["roomStatus", "roomData", "data", "rooms"]
            for key in possibleKeys {
                if let roomData = jsonObject[key] as? [String: Any],
                   let nestedData = try? JSONSerialization.data(withJSONObject: roomData),
                   let roomStatus = try? decoder.decode(RoomStatusResponse.self, from: nestedData) {
                    print("✅ Decoded from \(source) - direct key: \(key)")
                    return roomStatus
                }
            }
        }
        
        return nil
    }
    
    /// Get formatted timestamp from ISO string
    static func formatTimestamp(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else {
            return "Unknown"
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d, h:mm a"
        return displayFormatter.string(from: date)
    }
    
    /// Get relative time (e.g., "2 min ago")
    static func relativeTime(from isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else {
            return "Unknown"
        }
        
        let now = Date()
        let interval = now.timeIntervalSince(date)
        
        let minutes = Int(interval / 60)
        if minutes < 1 {
            return "Just now"
        } else if minutes < 60 {
            return "\(minutes) min ago"
        } else {
            let hours = minutes / 60
            return "\(hours)h ago"
        }
    }
    
    /// Get time remaining until end of booking
    static func timeRemaining(until endTime: String) -> String? {
        let formatter = ISO8601DateFormatter()
        guard let endDate = formatter.date(from: endTime) else {
            return nil
        }
        
        let now = Date()
        let interval = endDate.timeIntervalSince(now)
        
        if interval < 0 {
            return nil
        }
        
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
    }
}

// MARK: - Errors
enum RoomStatusError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(String)
    case htmlResponse
    case allEndpointsFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let details):
            return "Failed to decode room data: \(details)"
        case .htmlResponse:
            return "Received HTML instead of JSON - API endpoint may be incorrect"
        case .allEndpointsFailed:
            return "All API endpoints failed - server may be blocking app requests"
        }
    }
}
